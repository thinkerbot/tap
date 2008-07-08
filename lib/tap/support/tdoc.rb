#require 'tap/env'
#require 'tap/support/tdoc/config_attr'
# require 'singleton'
require 'strscan'

module Tap
  module Support
    
    # == Overview
    # TDoc hooks into and extends RDoc to make task documentation available for command line
    # applications as well as for inclusion in RDoc html.  In particular, TDoc makes available
    # documentation for Task configurations, when they are present.  TDoc provides an extension
    # to the standard RDoc HTMLGenerator and template.  
    #
    # === Usage
    # To generate task documentation with configuration information, TDoc must be loaded and 
    # the appropriate flags passed to rdoc .  Essentially what you want is:
    #
    #   % rdoc --fmt tdoc --template tap/support/tdoc/tdoc_html_template [file_names....]
    #
    # Unfortunately, there is no way to load or require a file into the rdoc utility directly; the 
    # above code causes an 'Invalid output formatter' error.  However, TDoc is easy to utilize 
    # from a Rake::RDocTask:
    #
    #   require 'rake'
    #   require 'rake/rdoctask'
    #
    #   desc 'Generate documentation.'
    #   Rake::RDocTask.new(:rdoc) do |rdoc|
    #     require 'tap/support/tdoc'
    #     rdoc.template = 'tap/support/tdoc/tdoc_html_template' 
    #     rdoc.options << '--fmt' << 'tdoc'
    #  
    #     # specify whatever else you need
    #     # rdoc.rdoc_files.include(...)
    #   end
    #
    # Now execute the rake task like:
    #
    #   % rake rdoc
    #
    # TDoc may also be utilized programatically, but you should be aware that RDoc in Ruby
    # can raise errors and/or cause namespace conflicts (see below).
    #
    # === Implementation
    # RDoc is a beast to utilize in a  non-standard way.  One way to make RDoc parse unexpected
    # flags like 'config_accessor' or the 'c' config specifier is to use the '--accessor' option
    # (see 'rdoc --help' or the RDoc documentation for more details).  
    #
    # TDoc hooks into the '--accessor' parsing process to pull out configuration attributes and
    # format them into their own Configuration section on an RDoc html page.  When 'tdoc' is
    # specified as an rdoc option, TDoc in effect sets accessor flags for all the standard Task
    # configuration methods, and then extends the RDoc::RubyParser handle these specially.  
    #
    # If 'tdoc' is not specified as the rdoc format, TDoc does not affect the RDoc output.
    # Similarly, the configuration attributes will not appear in the output unless you specify a 
    # template that utilizes them.
    #
    # === Namespace conflicts
    # RDoc creates a namespace conflict with other libraries that define RubyToken and RubyLex
    # in the Object namespace (the prime example being IRB).  TDoc checks for such a conflict
    # and redfines the RDoc RubyToken and RubyLex within the RDoc namespace. Essentially:
    #
    #   RubyToken => RDoc::RubyToken
    #   RubyLex => RDoc::RubyLex
    #
    # The redefinition should not affect the existing RubyToken and RubyLex constants, but if 
    # you directly use the RDoc versions after loading TDoc, you should be aware that they must 
    # be accessed through the new constants.  Unfortunatley the trick is not seamless.  The RDoc 
    # RubyLex makes a few calls to the RubyLex class method 'debug?'... these will be issued to 
    # the existing RubyLex method and not RDoc::RubyLex.debug?
    #
    # In addition, because of the RubyLex calls, the RDoc::RubyLex cannot be fully hidden when 
    # TDoc is loaded before the conflicting RubyLex; you cannot load TDoc before loading IRB 
    # without raising warnings.  I hope to submit a patch for RDoc to stop this nonsense in the 
    # future.
    #
    # On the plus side, you can now access/use RDoc within irb by requiring 'tap/support/tdoc'.
    # 
    class TDoc 

      class << self
        
        # Hash of generated TDocs, keyed by file.
        attr_reader :docs
        
        # Clears existing TDocs.
        def clear
          @docs = {}
        end
        
        def parse(str, klass)
          tdocs = {}
          scanner = case str
          when StringScanner then str
          when String then StringScanner.new(str)
          else raise ArgumentError, "expected StringScanner or String"
          end
          
          CDoc.parse(scanner) do |namespace, key, value, comment|
            class_name = namespace.empty? ? klass.to_s : namespace
            tdoc = (docs[class_name] ||= TDoc.new(class_name))
            
            case key
            when 'manifest'
              tdoc.summary = value
              tdoc.desc = comment
            when 'args'
              tdoc.args = value
              # any use for comment?
            when 'source_file'
              tdoc.source_file = value
            else
              raise "unknown config key: #{namespace}::#{key}" # TODO -- new type of error
            end
            
            tdocs[tdoc] ||= scanner.pos
          end
          
          if tdocs.find {|tdoc, first_pos| tdoc.args == nil }
            # sort out the ranges between first-declarations for the tdocs
            sorted_tdocs = tdocs.to_a.sort_by {|tdoc, first_pos| first_pos }
            sorted_tdocs.each_with_index do |(tdoc, first_pos), i|
              tdocs[tdoc] = [first_pos, sorted_tdocs[i+1] || scanner.string.length]
            end
            
            tdocs.each_pair do |tdoc, (range_begin, range_end)|
              next if tdoc.args
              tdoc.args = parse_process_args(scanner, range_begin, range_end)
            end
          end

          tdocs.keys
        end
        
        # try to parse arguments from the process method
        # if no args have been explicitly stated for a 
        # particular tdoc.  this is a tricky thing to do
        # without having knowledge of the ruby code (as
        # TDoc attempts to do, to speed parsing), and
        # requires an assumption for the case where multiple
        # tdocs are present in a single string. Assumption:
        # - if the args are not explicitly stated, then
        #   the process method will occur BETWEEN the
        #   first declarations for a given tdoc.
        #
        # ex:
        #
        #   # First::Class::manifest
        #   class First::Class
        #     def process() end
        #   end
        #   # Second::Class::manifest
        #   class Second::Class
        #     def process() end
        #   end
        #
        # rather than:
        #
        #   # First::Class::manifest
        #   class First::Class
        #     def process() end
        #   end
        #   class Second::Class
        #     def process() end
        #   end
        #   # Second::Class::manifest
        #
        def parse_process_args(scanner, range_begin, range_end)

          # parse for the process args, checking that the
          # args are where they are expected to be
          scanner.pos = range_begin
          return nil unless scanner.skip_until(/^\s*def\s+process\(/) != nil
            
          args = scanner.scan_until(/\)/).to_s.chomp(')').split(',').collect do |arg|
            arg = arg.strip.upcase
            case arg
            when /^&/ then nil
            when /^\*/ then arg[1..-1] + "..."
            else arg
            end

          end.compact

          if args && scanner.pos >= range_end
            raise "ranges for scanning process arguments are mixed"
          end
          
          args
        end

        # Returns the TDoc for the specified class or path.
        #--
        # Generates if necessary
        def [](klass, search_paths=$:)
          # case 
          #  when docs.has_key?(klass)
          #    docs[klass] 
          #    
          #  when klass.include?(Tap::Support::Framework) 
          #    source_files = Root.sglob(klass.default_name + '.rb', *search_paths)
          #    source_file = case source_files.length
          #    when 1 then source_files.first
          #    when 0
          #      raise ArgumentError.new("no source file found for: #{klass}")
          #    else
          #      raise ArgumentError.new("multiple source files found for: #{klass}")
          #    end
          #    
          #    # clean this crap up, should all be one method.  Tdoc should track
          #    # the klass as well?  Big trick will be to tokenize config lines
          #    # to eol, pull out key and default.  The klass actually should NOT
          #    # be necessary except for figuring some default names.
          #    #
          #    # Expand tdoc syntax to allow multiple tdocs per file:
          #    # :Description (class): 
          #    # :Usage (class):
          #    #
          #    # Then consider the expected class by source file as the default.
          #    # Maybe eliminate usage and simply pull the process args?  Drill
          #    # back for process args if no process is specified, using 
          #    # klass.superclass?  Should not try to be too clever on this
          #    # point.   
          #    source = File.read(source_file)

          #      
          #      unless klass.configurations.empty?
          #        lines = scanner.string.split(/\r?\n/)
          #        klass.configurations.each do |receiver, key, config|
          #          next unless receiver == klass
          #          # -1 .. starts counting at one
          #          tdoc.config[key] = (lines[config.line-1] =~ /^[^#]+#(.*)$/) ? $1.strip : ""
          #        end
          #      end
          #    end
          #    
          #  else
          #    raise ArgumentError.new("not a Framework class: #{klass}")
          #  end
        end
        
        def usage(program_file)
          comment = []
          File.open(program_file) do |file|
            while line = file.gets
              case line
              when /^\s*$/ 
                # skip leading blank lines
                comment.empty? ? next : break
              when /^\s*# ?(.*)/m
                comment << $1
              end
            end
          end
          
          comment.join('').rstrip
        end
        

      end
      
      clear
      
      # Summary line used in manifest
      attr_accessor :summary
    
      # Program usage printed in program help
      attr_accessor :usage
    
      # Hash of config descriptions printed in program help
      attr_reader :config
      
      attr_accessor :class_name
      
      def initialize(class_name)#summary=nil, desc=[], usage=nil, config={})
        @class_name = class_name
        # @summary = summary
        # @desc = desc
       # @usage = usage
       # @config = config
      end
      
      # Returns the full description, in lines wrapped to the number of specified cols
      # and with tabs expanded with tabsize spaces.  
      #
      # If cols==nil, then the lines will be returned at their full length, with no tab
      # expansion.
      def desc(cols=nil, tabsize=2)
        if cols == nil
          @desc
        else
          
          # wrapping algorithm is slightly modified from 
          # http://blog.macromates.com/2006/wrapping-text-with-regular-expressions/
          
          @desc.collect do |line|
            next(line) if line =~ /^\s*$/
            line.gsub(/\t/, " " * tabsize).gsub(/(.{1,#{cols}})( +|$\r?\n?)|(.{1,#{cols}})/, "\\1\\3\n").split(/\s*\n/)
          end.flatten
        end
      end
      
      def empty?
        @summary == nil &&
        @usage == nil &&
        @desc.empty? &&
        @config.empty? 
      end

    end
  end
end


#require 'tap/env'
# require 'tap/support/tdoc/config_attr'
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
        
        def parse(str)
          tdoc = TDoc.new
          scanner = StringScanner.new(str)
          
          # Parse Summary and Description
          unless scanner.skip_until(DESC_BEGIN_REGEXP) == nil
            tdoc.summary = scanner.scan_until(/$/).strip
            
            line_fragments = []
            while comment = scanner.scan(/^\s*#.*$/)
              case comment
              when DESC_END_REGEXP 
                # break if the description end is reached
                break
              when /^\s*#\s?((\s*).*)$/
   
                # collect continuous description line
                # fragments and join into a single line
                case
                when $1 == $2 
                  # empty comment line
                  unless line_fragments.empty?
                    tdoc.desc << line_fragments.join(' ') 
                    line_fragments = []
                  end
                  
                  tdoc.desc << ""
                when $2.empty? 
                  # continuation line
                  line_fragments << $1.rstrip
                else 
                  # indented line
                  unless line_fragments.empty?
                    tdoc.desc << line_fragments.join(' ') 
                    line_fragments = []
                  end
                  
                  tdoc.desc << $1.rstrip
                end
              end
            end
            
            unless line_fragments.empty?
              tdoc.desc << line_fragments.join(' ') 
            end
          end
          
          # Parse Usage
          unless scanner.skip_until(USAGE_REGEXP) == nil
            tdoc.usage = scanner.scan_until(/$/).strip
          end
          
          # Yield for additional parsing
          yield(scanner, tdoc) if block_given?

          tdoc
        end
        
        # Returns the TDoc for the specified class or path.
        #--
        # Generates if necessary
        def [](klass_or_path, search_paths=$:)
          case 
          when docs.has_key?(klass_or_path)
            docs[klass_or_path] 
            
          when klass_or_path.kind_of?(String) && File.file?(klass_or_path)
            path = File.expand_path(klass_or_path)
            docs[path] = parse(File.read(path))

          when klass_or_path.kind_of?(Class) 
            source_file = klass_or_path.respond_to?(:source_file) ?
              klass_or_path.source_file : nil
              
            if source_file == nil
              source_files = Root.sglob(klass_or_path.to_s.underscore + '.rb', *search_paths)
              source_file = case source_files.length
              when 1 then source_files.first
              when 0
                raise ArgumentError.new("no source file found for: #{klass_or_path}")
              else
                raise ArgumentError.new("multiple source files found for: #{klass_or_path}")
              end
            end
            
            self[source_file]
          
          else
            raise ArgumentError.new("not a Class or existing file: #{klass_or_path}")
          end
        end
        
        protected
        
        def mregexp(modifier)
          Regexp.new("#\s*:#{modifier}:")
        end
      end
      
      clear
      
      DESC_BEGIN_REGEXP = mregexp('desc')
      DESC_END_REGEXP = mregexp('cesd')
      USAGE_REGEXP = mregexp('usage')
  
      # Summary line used in manifest
      attr_accessor :summary
    
      # Full description printed in program help
      attr_reader :desc
    
      # Program usage printed in program help
      attr_accessor :usage
    
      # Hash of config descriptions printed in program help
      attr_reader :config
      
      def initialize(summary=nil, desc=[], usage=nil, config={})
        @summary = summary
        @desc = desc
        @usage = usage
        @config = config
      end

      # when scanner.skip_until(/^\s*def\s+process\(/) != nil
      #   scanner.scan_until(/\)/).to_s.split(',').collect do |arg|
      #     arg = arg.strip.upcase
      #     case arg
      #     when /^&/ then nil
      #     when /^\*/ then arg[1..-1] + "..."
      #     else arg
      #     end
      #   end.compact.join(' ')
      # else nil
      # end
      
      
      # class << self
      #   def search_for_files(base_paths, path_suffix)
      #     # modified from 'activesupport/dependencies'
      #     path_suffix = path_suffix + '.rb' unless path_suffix =~ /\.rb$/
      #     Root.sglob(path_suffix, *base_paths)
      #   end
      # end
      #attr_accessor :stats, :options, :documented_files, :load_paths
      
      # def reinitialize(argv=['--fmt', 'tdoc', '--quiet'])
      #   @documented_files = []
      #   @tl = RDoc::TopLevel::reset
      #   @stats = RDoc::Stats.new
      #   @options = Options.instance
      #   @options.parse(argv, RDoc::RDoc::GENERATORS)
      #   @load_paths = Tap::Env.instance.nil? ? $: : Tap::Env.instance.load_path_targets.flatten
      # end
      
      # def search_for_source_files(klass)
      #   source_files = []
      #   # searches back for all configurable source files, so that
      #   # inherited configs can be documented.
      #   while klass.kind_of?(Tap::Support::ConfigurableMethods)
      #     source_files.concat(search_for_files(klass.to_s.underscore))
      #     klass = klass.superclass
      #   end
      #   
      #   source_files.uniq
      # end
      
      # def document(*filepaths)
      #   filepaths.each do |filepath|
      #     next if filepath == nil || instance.documented_files.include?(filepath) || !File.exists?(filepath)
      # 
      #     tl = RDoc::TopLevel.new(filepath)
      #     parser = RDoc::RubyParser.new(tl, filepath, File.read(filepath), instance.options, instance.stats)
      #     parser.scan
      #     instance.documented_files << filepath
      #   end
      # end
      # 
      # def find_class_or_module_named(name)
      #   RDoc::TopLevel.all_classes_and_modules.each do |c|
      #     res = c.find_class_or_module_named(name) 
      #     return res if res
      #   end
      #   nil
      # end
    
      # def [](klass)      
      #   name = klass.to_s
      #   res = find_class_or_module_named(name)
      # 
      #   # If no result was found, try to document a sourcefile
      #   # from the standard filepath and search again 
      #   if res == nil 
      #     source_files = klass.respond_to?(:source_files) ? klass.source_files : []
      #     source_files = search_for_source_files(klass) if source_files.empty?
      #   
      #     unless source_files.empty?
      #       document(*source_files) 
      #       res = find_class_or_module_named(name)
      #     end
      #   end
      #   
      #   res
      # end

      def cmd_usage(program_file, sections=[], keep_section_headers=false)
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
        
        unless sections.empty?
          sections_hash = {}
          current_section = nil
          comment.each do |line|
            case line
            when /^s*=+(.*)/
              current_section = []
              current_section << line if keep_section_headers
              sections_hash[$1.strip] = current_section
            else
              current_section << line unless current_section.nil?
            end
          end
          
          comment = []
          sections.each do |section|
            next unless sections_hash.has_key?(section)
            comment.concat(sections_hash[section])
          end
        end
        
        comment.join('')
      end
      
    end
  end
end


# RDoc creates a namespace conflict with IRB within 'rdoc/parsers/parse_rb'
# In that file, RubyToken and RubyLex get defined in the Object namespace,
# which will conflict with prior definitions from, for instance, IRB.  
#
# This code redefines the RDoc RubyToken and RubyLex within the RDoc 
# namespace.  RDoc is not affected because all includes and uses of 
# RubyToken and RubyLex are set when RDoc is loaded.  The single exception
# I know of are several calls to class methods of RubyLex (ex RubyLex.debug?).
# These calls will be routed to the existing RubyLex.
#
# Uses of the existing RubyToken and RubyLex (as by irb) should be 
# unaffected as the constants are reset after RDoc loads.
#
if Object.const_defined?(:RubyToken) || Object.const_defined?(:RubyLex)
  class Object 
    old_ruby_token = const_defined?(:RubyToken) ? remove_const(:RubyToken) : nil
    old_ruby_lex = const_defined?(:RubyLex) ? remove_const(:RubyLex) : nil
  
    require 'rdoc/rdoc'

    # if by chance rdoc has ALREADY been loaded then requiring
    # rdoc will not reset RubyToken and RubyLex... in this case
    # the old constants are what you want.
    new_ruby_token = const_defined?(:RubyToken) ? remove_const(:RubyToken) : old_ruby_token
    new_ruby_lex = const_defined?(:RubyLex) ? remove_const(:RubyLex) : old_ruby_lex
    
    RDoc.const_set(:RubyToken, new_ruby_token)
    RDoc.const_set(:RubyLex, new_ruby_lex)
  
    const_set(:RubyToken, old_ruby_token) unless old_ruby_token == nil
    const_set(:RubyLex, old_ruby_lex) unless old_ruby_lex == nil
  end
else
  require 'rdoc/rdoc'

  if Object.const_defined?(:RubyToken) && !RDoc.const_defined?(:RubyToken)
    class Object
      RDoc.const_set(:RubyToken, remove_const(:RubyToken))
    end
  end 
  
  if Object.const_defined?(:RubyLex) && !RDoc.const_defined?(:RubyLex)
    class Object
      RDoc.const_set(:RubyLex, remove_const(:RubyLex))
      RDoc::RubyLex.const_set(:RubyLex, RDoc::RubyLex)
    end
  end
end

module Tap
  module Support
    class TDoc
    
      # Encasulates information about the configuration.  Designed to be utilized
      # by the TDocHTMLGenerator as similarly as possible to standard attributes.
      class ConfigAttr < RDoc::Attr
        # Contains the actual declaration for the config attribute. ex:  "c [:key, 'value']      # comment"
        attr_accessor :config_declaration, :default
        
        def initialize(*args)
          @comment = nil # suppress a warning in Ruby 1.9
          super
        end
        
        alias original_comment comment
        
        def desc
          case text.to_s 
          when /^#--(.*)/ then $1.strip
          when /^#(.*)/ then $1.strip
          else
            nil
          end
        end
        
        # The description for the config.  Comment is formed from the standard 
        # attribute comment and the text following the attribute, which is slightly
        # different than normal:
        #
        #   # standard comment
        #   attr_accessor :attribute              
        #
        #  # standard comment
        #  config_accessor :config    # ...added to standard comment
        #
        #  c [:key, 'value']           # hence you can comment inline like this.
        #
        # The comments for each of these will be:
        # attribute:: standard comment
        # config:: standard comment ...added to standard comment
        # key:: hence you can comment inline like this.
        #
        def comment(add_default=true)
          text_comment = text.to_s.sub(/^#--.*/m, '')
          original_comment.to_s + text_comment + (default && add_default ? " (#{default})" : "")
        end
      end
      
      module CodeObjectAccess # :nodoc:
        def comment_sections(section_regexp=//, normalize_comments=false)
          res = {}

          section = nil
          lines = []
          comment_lines = comment.split(/\r?\n/)
          comment_lines << nil
          comment_lines.each do |line|
            case line
            when nil, /^\s*#\s*=+(.*)/
              next_section = (line == nil ? nil : $1.to_s.strip)

              if section =~ section_regexp
                lines << "" unless normalize_comments
                res[section] = lines.join("\n") unless section == nil
              end

              section = next_section
              lines = []
            else
              if normalize_comments
                line =~ /^\s*#\s?(.*)/
                line = $1.to_s
              end

              lines << line
            end
          end

          res
        end
      end
      
      module ClassModuleAccess # :nodoc:
        def find_class_or_module_named(name)
          return self if full_name == name
          (@classes.values + @modules.values).each do |c| 
            res = c.find_class_or_module_named(name)
            return res if res
          end
          nil
        end
        
        def configurations
          @attributes.select do |attribute|
            attribute.kind_of?(TDoc::ConfigAttr)
          end
        end
        
        def find_configuration_named(name)
          @attributes.each do |attribute|
            next unless attribute.kind_of?(TDoc::ConfigAttr)
            return attribute if attribute.name == name
          end
          nil
        end
      end
  
      # Overrides the new method automatically extend the new object with
      # ConfigParser.  Intended to be used like:
      #   RDoc::RubyParser.extend InitializeConfigParser
      module InitializeConfigParser # :nodoc:
        def new(*args)
          parser = super
          parser.extend ConfigParser
          #parser.config_mode = 'config_accessor'
          parser
        end
      end
      
      # Provides methods extending an RDoc::RubyParser such that the parser will produce 
      # TDoc::ConfigAttr instances in the place of RDoc::Attr instances during attribute
      # parsing. 
      module ConfigParser # :nodoc:
        include RDoc::RubyToken
        include TokenStream
                 
        CONFIG_ACCESSORS = ['config', 'config_attr']        

        # Gets tokens until the next TkNL
        def get_tk_to_nl
          tokens = []
          while !(tk = get_tk).kind_of?(TkNL)
            tokens.push tk
          end
          unget_tk(tk)
          tokens
        end

        # Works like the original parse_attr_accessor, except that the arg
        # name is parsed from the config syntax and added attribute will
        # be a TDoc::ConfigAttr.  For example:
        #
        #   class TaskDoc < Tap::Task
        #     config [:key, 'value']   # comment
        #   end
        #
        # produces an attribute named :key in the current config_rw mode.
        #
        # (see 'rdoc/parsers/parse_rb' line 2509)
        def parse_config(context, single, tk, comment)
          tks = get_tk_to_nl
          
          key_tk = nil
          value_tk = nil

          tks.each do |token|
            next if token.kind_of?(TkSPACE)
            
            if key_tk == nil
              case token
              when TkSYMBOL then key_tk = token
              when TkLPAREN then next
              else break
              end
            else
              case token
              when TkCOMMA then value_tk = token
              else
                value_tk = token if value_tk.kind_of?(TkCOMMA)
                break
              end
            end
          end

          text = ""
          if tks.last.kind_of?(TkCOMMENT)
            text = tks.last.text.chomp("\n").chomp("\r")
            unget_tk(tks.last)
              
            # If nodoc is given, don't document
              
            tmp = RDoc::CodeObject.new
            read_documentation_modifiers(tmp, RDoc::ATTR_MODIFIERS)
            text = nil unless tmp.document_self
          end
          
          tks.reverse_each {|token| unget_tk(token) }
          return if key_tk == nil || text == nil
          
          arg = key_tk.text[1..-1]
          default = nil
          if value_tk
            if text =~ /(.*):no_default:(.*)/
              text = $1 + $2
            else
              default = value_tk.text
            end
          end
          att = TDoc::ConfigAttr.new(text, arg, "RW", comment)
          att.config_declaration = get_tkread
          att.default = default
           
          context.add_attribute(att)
        end
        
        # Overrides the standard parse_attr_accessor method to hook in parsing
        # of the config accessors.  If the input token is not named as one of the
        # CONFIG_ACCESSORS, it will be processed normally.
        def parse_attr_accessor(context, single, tk, comment)
          case tk.name
          when 'config', 'config_attr'
              parse_config(context, single,  tk, comment)
          else
            super
          end
        end
      end
    end
  end
end

# Register the TDoc generator (in case you want to actually use it).
# method echos RDoc generator registration (see 'rdoc/rdoc' line 76)
Generator = Struct.new(:file_name, :class_name, :key)
RDoc::RDoc::GENERATORS['tdoc'] = Generator.new(
  "tap/support/tdoc/tdoc_html_generator.rb",
  "TDocHTMLGenerator".intern,
  "tdoc")

# Add the extended accessors to context classes.
module RDoc # :nodoc:
  class CodeObject # :nodoc:
    include Tap::Support::TDoc::CodeObjectAccess  
  end
  
  class ClassModule # :nodoc:
    include Tap::Support::TDoc::ClassModuleAccess
  end
end

# Override methods in Options to in effect incorporate the accessor 
# flags for TDoc parsing. (see 'rdoc/options')  Raise an error if an
# accessor flag has already been specified. 
class Options # :nodoc:
  alias tdoc_original_parse parse
  
  def parse(argv, generators)
    tdoc_original_parse(argv, generators)
    return unless @generator_name == 'tdoc'
    
    accessors = Tap::Support::TDoc::ConfigParser::CONFIG_ACCESSORS
    
    # check the config_accessor_flags for accessor conflicts
    extra_accessor_flags.each_pair do |accessor, flag|
      if accessors.include?(accessor)
        raise OptionList.error("tdoc format already handles the accessor '#{accessor}'")
      end
    end
    
    # extra_accessors will be nil if no extra accessors were 
    # specifed, otherwise it'll be a regexp like /^(...)$/
    # the string subset assumes
    #   regexp.to_s # => /(?-mix:^(...)$)/  
    @extra_accessors ||= /^()$/ 
    current_accessors_str = @extra_accessors.to_s[9..-4]
    
    # echos the Regexp production code in rdoc/options.rb
    # (see the parse method, line 501)
    re = '^(' + current_accessors_str + accessors.map{|a| Regexp.quote(a)}.join('|') + ')$' 
    @extra_accessors = Regexp.new(re)
    
    RDoc::RubyParser.extend Tap::Support::TDoc::InitializeConfigParser 
  end
end
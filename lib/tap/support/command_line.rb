require 'optparse'

module Tap
  module Support
    
    # Under Construction
    module CommandLine
      module_function

      # Parses the input string as YAML, if the string matches the YAML document 
      # specifier (ie it begins with "---\s*\n").  Otherwise returns the string.
      #
      #   str = {'key' => 'value'}.to_yaml       # => "--- \nkey: value\n"
      #   Tap::Script.parse_yaml(str)            # => {'key' => 'value'}
      #   Tap::Script.parse_yaml("str")          # => "str"
      def parse_yaml(str)
        str =~ /\A---\s*\n/ ? YAML.load(str) : str
      end
      
      def shift(argv)
        index = nil
        argv.each_with_index do |arg, i|
          if arg !~ /\A-/
            index = i 
            break
          end
        end
        index == nil ? nil : argv.delete_at(index)
      end

      def usage(path, cols=80)
        parse_usage(File.read(path), cols)
      end
        
      def parse_usage(str, cols=80)
        scanner = StringScanner.new(str)
        scanner.scan(/^#!.*?$/)
        Comment.parse(scanner, false).wrap(cols, 2).strip
      end
      
      def configv(config)
        desc = config.desc
        desc.extend(OptParseComment) if desc.kind_of?(Comment)
          
        [config.short, argtype(config), desc].compact
      end
      
      def argtype(config)
        case config.arg_type
        when :optional 
          "#{config.long} [#{config.arg_name}]"
        when :switch 
          config.long(true)
        when :flag
          config.long
        when :list
          "#{config.long} a,b,c"
        when :mandatory, nil
          "#{config.long} #{config.arg_name}"
        else
          raise "unknown arg_type: #{config.arg_type}"
        end
      end
      
      module OptParseComment
        def empty?
          to_str.empty?
        end

        def to_str
          subject.to_s =~ /#(.*)$/ ? $1.strip : ""
        end
      end
    end
  end
end
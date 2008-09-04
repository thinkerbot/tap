require 'optparse'
require 'tap/patches/optparse/summarize'

module Tap
  module Support
    
    # Under Construction
    module CommandLine
      module_function

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
          # currently removes the :no_default: document modifier
          # which is used during generation of TDoc
          subject.to_s =~ /#\s*(:no_default:)?\s*(.*)$/ ? $2.strip : ""
        end
      end
    end
  end
end
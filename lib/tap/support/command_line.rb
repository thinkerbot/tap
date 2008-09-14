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
    end
  end
end
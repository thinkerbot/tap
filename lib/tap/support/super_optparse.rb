require 'optparse'
require 'tap/patches/optparse/summarize'

module Tap
  module Support
    class SuperOptionParser < OptionParser
      SUPER_OPT_REGEXP = /^-(\w|-\w+)-$/
      
      def parse!(argv=ARGV)
        args = []
        super_args = []
        
        share = false
        while !argv.empty?
          arg = argv.shift
          
          if arg =~ SUPER_OPT_REGEXP
            super_args << arg.chomp('-')
            share = true
          else 
            super_args << arg if share
            args << arg
            share = false
          end
        end

        argv.concat(args)
        super(super_args)
      end
    end 
  end
end
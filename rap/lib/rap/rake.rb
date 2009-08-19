require 'rubygems'
require 'rake'

module Rap

  # :startdoc::task run rake tasks
  # 
  # Simply enques the specified rake task(s) for execution.  Useful when a
  # rake task needs to be executed within a workflow.  For example these
  # are equivalent:
  #
  #   % rap rake test
  #   % rake test
  # 
  # The only exeception is in the use of the --help option.  Use --rake-help
  # to access the rake help, and --help to access this help.
  #
  class Rake < Tap::Task
    class << self
      
      def parse!(argv, app=Tap::App.instance) # => instance, argv
        if argv.include?('--help')
          puts help
          exit
        end
        argv.collect! {|arg| arg == '--rake-help' ? '--help' : arg}
        
        [new({}, app), argv]
      end
      
      # Returns true if Rake detects a rakefile.
      def has_rakefile?
        ::Rake.application.have_rakefile != nil
      end
    end
    
    # Executes Rake using the input arguments as if they came from the
    # command line.
    def process(*argv)
      rake = ::Rake.application
  
      # run as if from command line using argv
      current_argv = ARGV.dup
      begin
        ARGV.clear
        ARGV.concat(argv)

        # now follow the same protocol as 
        # in run, handling options
        rake.init
        rake.load_rakefile
      ensure
        ARGV.clear
        ARGV.concat(current_argv)
      end

      rake.top_level
    
      nil
    end
  end
end
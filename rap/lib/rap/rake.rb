require 'rubygems'
require 'rake'

module Rap

  # :startdoc::task run rake tasks
  # 
  # Simply enques the specified rake task(s) for execution.  Useful when a
  # rake task needs to be executed within a workflow.  For example these
  # are equivalent:
  #
  #   % tap run -- rake test
  #   % rake test
  # 
  # The only exeception is in the use of the --help option.  Use --rake-help
  # to access the rake help, and --help to access this help.
  #
  class Rake < Tap::Task
    class << self
  
      # Overrides Tap::Support::FrameworkClass#parse! to do  
      # nothing so that all args get passed forward to rake.
      def parse!(argv, app=Tap::App.instance) # => instance, argv
        if argv.include?('--help')
          puts help
          exit
        end
        argv = argv.collect {|arg| arg == '--rake-help' ? '--help' : arg}
        
        puts argv
        [new({}, default_name, app), argv]
      end
    end
  
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
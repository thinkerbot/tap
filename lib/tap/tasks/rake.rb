require 'rake'
require 'tap/support/rake'

module Tap
  module Tasks
    # :startdoc::manifest run rake tasks
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
    
      # Modifies Rake::Application by adding a hook to the standard_exception_handling
      # method.  This allows more fine-grained use of Rake::Applications by Tap.
      module Application
        def enq_top_level(app)
          # takes the place of rake.top_level
          if options.show_tasks
            display_tasks_and_comments
            exit
          elsif options.show_prereqs
            display_prerequisites
            exit
          else
            top_level_tasks.each do |task_string|
              name, args = parse_task_string(task_string)
              task = self[name]
            
              unless task.kind_of?(Tap::Support::Executable)
                Tap::Support::Executable.initialize(task, :invoke)
              end
            
              app.enq(task, *args)
            end
          end  
        end
      end
    
      class << self
      
        # Overrides Tap::Support::FrameworkClass#instantiate to do  
        # nothing so that all args get passed forward to rake.
        def instantiate(argv, app=Tap::App.instance) # => instance, argv
          if argv.include?('--help')
            puts help
            exit
          end
          [new({}, default_name, app), argv.collect {|arg| arg == '--rake-help' ? '--help' : arg}]
        end
      end
    
      #--
      # def on_complete(override=false, &block)
      #   @rake_tasks.each do |task|
      #     task.on_complete(override, &block)
      #   end
      # end
      #++
      
      def enq(*argv)
        rake = ::Rake.application
        unless rake.kind_of?(Application)
          rake.extend Application
        end

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
      
        rake.enq_top_level(app)
      
        nil
      end
    end
  end
end
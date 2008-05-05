require 'rake'

module Tap
  module Support
    
    # Used to modify an App so that it will lookup Rake tasks as well as Tap tasks.  Simply use:
    #   app.extend(RakeLookup)
    #--
    # Note: Do not refactor Tap:Support::Rake without attending  to the line in 'script/run' that 
    # extends app.  As it stands, this module is loaded as needed using Dependencies.
    module Rake 

      # Modifies Rake::Task to behave like Tap::Task.  The essential code is this:
      #
      #   module Tap::Support::Rake::Task
      #     def new(*args)
      #       task = super
      #       Tap::Task::Base.initialize(task, :invoke)
      #       task
      #     end
      #   end
      #
      # Here the new method creates a new Rake task as normal, then initializes the 
      # Rake task based on the invoke method.  The modifed code is applied to Rake
      # in the following fashion:
      #
      #   Rake::Task.extend(Tap::Support::Rake::Task)
      #
      module Task
        def new(*args)
          task = super
          Tap::Support::Executable.initialize(task, :invoke)
          task
        end
      end
      
      # Modifies Rake::Application by adding a hook to the standard_exception_handling
      # method.  This allows more fine-grained use of Rake::Applications by Tap.
      module Application
        attr_reader :on_standard_exception_block
        
        def self.extended(base)
          base.instance_variable_set('@on_standard_exception_block', nil)
        end
        
        # Sets a block to handle errors within standard_exception_handling.
        # Raises an error if the on_standard_exception_block is already
        # set and override is not specified. 
        #
        # If the error is handled in the on_standard_exception_block,
        # then the original standard_exception_handling will not be
        # invoked.
        def on_standard_exception(override=false, &block) # :yields: error
          unless on_standard_exception_block == nil || override
            raise "on_standard_exception_block already set: #{self}" 
          end
          @on_standard_exception_block = block
        end
        
        # Overrides the default standard_exception_handling to execute
        # the on_standard_exception_block, if set, before invoking the
        # original standard_exception_handling.  
        def standard_exception_handling
          super do
            begin
              yield
            rescue
              if on_standard_exception_block
                on_standard_exception_block.call($!)
              else raise
              end
            end
          end  
        end
        
        def argv_enq(app=App.instance) 
          # takes the place of rake.top_level
          if options.show_tasks
            display_tasks_and_comments
            exit
          elsif options.show_prereqs
            display_prerequisites
            exit
          else
            top_level_tasks.each do |task_name| 
              app.enq lookup(task_name)
            end
          end  
        end
        
      end
    end
  end
end

Rake::Task.extend(Tap::Support::Rake::Task)
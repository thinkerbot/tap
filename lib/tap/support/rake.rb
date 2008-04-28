require 'rake'

module Tap
  module Support
    
    # Used to modify an App so that it will lookup Rake tasks as well as Tap tasks.  Simply use:
    #   app.extend(RakeLookup)
    #--
    # Note: Do not refactor Tap:Support::Rake without attending  to the line in 'script/run' that 
    # extends app.  As it stands, this module is loaded as needed using Dependencies.
    module Rake
      def task(td, config={}, &block)
        Object::Rake.application.lookup(td) || super
      end

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
          Tap::Task::Base.initialize(task, :invoke)
          task
        end
      end
    end
  end
end

Rake::Task.extend(Tap::Support::Rake::Task)
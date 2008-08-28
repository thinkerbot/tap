module Tap
  module Tasks
    # :startdoc::manifest run rake tasks
    # 
    class Rake < Tap::Task
      class << self
        attr_reader :actions
        
        def inherited(child)
          super
          child.instance_variable_set(:@actions, actions.dup)
        end
      end
      
      instance_variable_set(:@actions, [])
      
      # List of sources for task.
      attr_writer :sources
      def sources
        @sources ||= []
      end

      # First source from a rule (nil if no sources)
      def source
        @sources.first if defined?(@sources)
      end
      
      # List of actions attached to a task.
      def actions
        self.class.actions 
      end
      
      def process(*args)
        actions.each do |action|
          case action.arity
          when 1 then action.call(self)
          else action.call(self, args)
          end
        end
        nil
      end
      
      def inspect
        "<#{self.class} #{name} => [#{dependencies.collect {|d,a| d}.join(', ')}]>"
      end
    end
  end
end
module Tap
  module Support
    
    # ExecutableQueue allows thread-safe enqueing and dequeing of 
    # Executable methods and inputs for execution.  
    class ExecutableQueue
      include MonitorMixin
      
      # Creates a new ExecutableQueue
      def initialize
        # required for MonitorMixin
        super()
        @queue = []
      end
      
      # Clears all methods and inputs.  Returns the existing queue as an array.
      def clear
        synchronize do
          current = self.queue
          self.queue = []
          current
        end
      end
      
      # Returns the number of enqueued methods
      def size
        queue.length
      end
      
      # True if no methods are enqueued
      def empty?
        queue.empty?
      end
      
      # Enqueues the method and inputs. Raises an error if the  
      # method is not an Executable.
      def enq(method, inputs)
        synchronize do
          check_method(method)
          queue.push [method, inputs]
        end
      end
      
      # Enqueues the method and inputs, but to the top of the queue.
      # Raises an error if the method is not an Executable.
      def unshift(method, inputs)
        synchronize do
          check_method(method)
          queue.unshift [method, inputs]
        end
      end
      
      # Dequeues the next method and inputs as an array like
      # [method, inputs]. Returns nil if the queue is empty.
      def deq
        synchronize { queue.shift }
      end
      
      def concat(array)
        synchronize do
          array.each do |method, inputs|
            enq(method, inputs)
          end
        end
      end
      
      # Converts self to an array.
      def to_a
        queue.dup
      end
      
      protected
      
      attr_accessor :queue # :nodoc:
      
      # Checks if the input method is extended with Executable
      def check_method(method) # :nodoc:
        raise "not Executable: #{method}" unless method.kind_of?(Executable)
      end
    end 
  end
end
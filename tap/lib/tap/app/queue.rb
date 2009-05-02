require 'monitor'
require 'tap/app/node'

module Tap
  class App
    
    # Queue allows thread-safe enqueing and dequeing of nodes and inputs for
    # execution.
    class Queue < Monitor
      
      attr_reader :queue
      
      # Creates a new Queue
      def initialize
        super
        @queue = []
      end
      
      # Clears self and returns an array of the enqueued methods and inputs,
      # organized by round.
      def clear
        synchronize do
          current = queue
          @queue = []
          current
        end
      end
      
      # Returns the number of enqueued methods
      def size
        synchronize do
          queue.size
        end
      end
      
      # True if no methods are enqueued
      def empty?
        synchronize { size == 0 }
      end
      
      # Enqueues the method and inputs. Raises an error if the  
      # method is not a Node.
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
      
      # Concats an array of [method, input] entries to self.
      def concat(entries)
        synchronize do
          entries.each do |method, inputs|
            enq(method, inputs)
          end
        end
      end
      
      # Dequeues the next method and inputs as an array like
      # [method, inputs]. Returns nil if the queue is empty.
      def deq
        synchronize { queue.shift }
      end
      
      # Converts self to an array.
      def to_a
        synchronize do
          queue.dup
        end
      end
      
      protected
      
      # Checks if the input method is extended with Node
      def check_method(method) # :nodoc:
        raise "not a node: #{method.inspect}" unless method.kind_of?(Node)
      end
    end 
  end
end
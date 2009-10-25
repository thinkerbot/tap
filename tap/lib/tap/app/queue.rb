require 'monitor'

module Tap
  class App
    
    # Queue allows thread-safe enqueing and dequeing of nodes and inputs for
    # execution.
    #
    # === API
    #
    # The following methods are required in alternative implementations of an
    # applicaton queue, where a job is a [node, inputs] array:
    #
    #   enq(node, inputs)     # pushes the job onto the queue
    #   unshift(node, inputs) # unshifts the job onto the queue
    #   deq                   # shifts a job off the queue
    #   size                  # returns the number of jobs in the queue
    #   clear                 # clears the queue, returns current jobs
    #   synchronize           # yields to the block
    #   to_a                  # returns the queue as an array
    #
    # Note that synchronize must be implemented even if it does nothing but
    # yield to the block.
    class Queue < Monitor
      
      # Creates a new Queue
      def initialize
        super
        @queue = []
      end
      
      # Enqueues the node and inputs as a job.
      def enq(node, inputs)
        synchronize do
          @queue.push [node, inputs]
        end
      end
      
      # Enqueues the node and inputs, but to the top of the queue.
      def unshift(node, inputs)
        synchronize do
          @queue.unshift [node, inputs]
        end
      end
      
      # Dequeues the next job as an array like [node, inputs]. Returns nil if
      # the queue is empty.
      def deq
        synchronize { @queue.shift }
      end
      
      # Returns the number of enqueued jobs.
      def size
        synchronize do
          @queue.size
        end
      end
      
      # Clears self and returns an array of the currently enqueued jobs.
      def clear
        synchronize do
          current = @queue
          @queue = []
          current
        end
      end
      
      # Returns the enqueued jobs as an array.
      def to_a
        synchronize do
          @queue.dup
        end
      end
    end 
  end
end
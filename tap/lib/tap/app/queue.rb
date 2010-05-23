module Tap
  class App
    
    # Queue allows enqueing and dequeing of tasks and inputs for execution.
    #
    # === API
    #
    # The following methods are required in alternative implementations of an
    # applicaton queue, where a job is a [task, input] array:
    #
    #   enq                   # pushes the job onto the queue
    #   deq                   # shifts a job off the queue
    #   size                  # returns the number of jobs in the queue
    #   clear                 # clears the queue, returns current jobs
    #
    # Note that synchronize must be implemented even if it does nothing but
    # yield to the block.
    class Queue
      
      # Creates a new Queue
      def initialize
        super
        @queue = []
      end
      
      # Enqueues the task and input.
      def enq(obj)
        @queue.push obj
      end
      
      # Dequeues the next job. Returns nil if the queue is empty.
      def deq
        @queue.shift
      end
      
      # Returns the number of enqueued jobs.
      def size
        @queue.size
      end
      
      # Clears self.
      def clear
        @queue = []
        self
      end
    end 
  end
end
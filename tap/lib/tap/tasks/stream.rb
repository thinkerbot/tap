require 'tap/tasks/load'

module Tap
  module Tasks
    
    # Stream recurrently loads data from $stdin by requeing self until an
    # end-of-file is reached.  This behavior is useful for creating tasks
    # that load a bit of data from an IO, send it into a workflow, and then
    # repeat.
    #
    # The eof cutoff can be modified using complete? method.  Streaming will
    # stop when complete? returns true.  For instance, this is a prompt task:
    #
    #   class Prompt < Tap::Tasks::Stream
    #     config :exit_seq, "\n"
    #
    #     def load(io)
    #       if io.eof?
    #         nil
    #       else
    #         io.readline
    #       end
    #     end
    #
    #     def complete?(io, line)
    #       line == nil || line == exit_seq
    #     end
    #   end
    #
    class Stream < Load
      
      # Loads data from io.  Process will open the input io object, load
      # a result, then check to see if the loading is complete (using the
      # complete? method).  Unless loading is complete, process will enque
      # io to self.  Process will close io when loading is complete, provided
      # use_close or file is specified.
      def process(io=$stdin)
        io = open(io)
        result = load(io)
        
        if complete?(io, result)
          if use_close || file
            close(io)
          end
        else
          reque(io)
        end
        
        result
      end
      
      # Returns true by default.  Override in subclasses to allow recurrent 
      # loading (see process).
      def complete?(io, last)
        io.eof?
      end
      
      # Reques self with io to the top of the queue.
      def reque(io)
        app.pq(self, [io])
      end
    end
  end
end

require 'monitor'
require 'tap/app/executable'

module Tap
  class App
    
    # ExecutableQueue allows thread-safe enqueing and dequeing of Executable
    # methods and inputs for execution.
    class ExecutableQueue < Monitor
      
      # Creates a new ExecutableQueue
      def initialize
        super
        @rounds = [[]]
      end
      
      # Clears self and returns an array of the enqueued methods and inputs,
      # organized by round.
      def clear
        synchronize do
          current, @rounds = @rounds, [[]]
          current
        end
      end
      
      # Returns the number of enqueued methods
      def size
        synchronize do
          size = 0 
          @rounds.each {|round| size += round.length }
          size
        end
      end
      
      # True if no methods are enqueued
      def empty?
        synchronize { size == 0 }
      end
      
      def has?(entry)
        synchronize do
          entry_id = entry.object_id
          
          @rounds.each do |round|
            round.each do |enqued_entry|
              return true if entry_id == enqued_entry.object_id
            end
          end
          false
        end
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
      
      # Enques an array of [method, inputs] entries as a round.  Rounds are
      # dequeued completely before the next round is dequeued.
      def concat(round)
        synchronize do
          round.each do |method, inputs|
            check_method(method)
          end
          
          @rounds << round
        end
      end
      
      # Converts self to an array.  If flatten is specified, all rounds are
      # concatenated into a single array.
      def to_a(flatten=true)
        synchronize do
          if flatten
            array = []
            @rounds.each {|round| array.concat(round) }
            array
          else
            @rounds.collect {|round| round.dup}
          end
        end
      end
      
      protected
      
      # Returns the active round.
      def queue # :nodoc:
        while @rounds.length > 1
          queue = @rounds[0]
          
          if queue.empty?
            @rounds.shift
          else
            return queue
          end
        end
        
        @rounds[0]
      end
      
      # Checks if the input method is extended with Executable
      def check_method(method) # :nodoc:
        raise "not executable: #{method.inspect}" unless method.kind_of?(Executable)
      end
    end 
  end
end
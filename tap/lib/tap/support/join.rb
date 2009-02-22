require 'configurable'

module Tap
  module Support
    
    # Joins create on_complete blocks which link together tasks (or more
    # generally, Executable objects) into workflows.  Joins support a 
    # variety of configurations which affect how one task passes inputs
    # to subsequent tasks.
    #
    class Join
      include Configurable
      
      # Causes the join to iterate the results
      # of the source when enquing the targets.
      config :iterate, false, :short => 'i', &c.boolean
      
      # Causes joins to splat ('*') the results
      # of the source when enquing the targets.
      config :splat, false, :short => 's', &c.boolean
      
      # Causes the targets to be enqued rather
      # than executed immediately.
      config :stack, false, :short => 'k', &c.boolean
      
      # Aggregates results and enques them to the target
      # in a trailing round.
      config :aggregate, false, :short => 'a', &c.boolean
      
      # Initializes a new join with the specified configuration.
      def initialize(config={})
        initialize_config(config)
      end
      
      # The name of the join, as a symbol.  By default name is the basename of
      # the underscored class name.
      def name
        File.basename(self.class.to_s.underscore).to_sym
      end
      
      # Creates a join that passes the results of each input to each output.
      def join(inputs, outputs)
        inputs.each do |input|
          input.on_complete do |_result|
            outputs.each do |output| 
              yield(_result) if block_given?
              enq(output, _result)
            end
          end
        end
      end
      
      # A hash of the configurations set to true.
      def options
        opts = config.to_hash
        opts.delete_if {|key, value| value == false }
        opts
      end
      
      # Returns a string like: "#<Join:object_id>"
      def inspect
        "#<Join:#{object_id}>"
      end
      
      protected
      
      # Enques the executable with the results, respecting the
      # configuration for self.
      #
      #                true                       false
      #   iterate      _results are iterated      _results are enqued directly
      #   splat        _results are splat enqued  _results are enqued directly
      #   stack        the executable is enqued   the executable is executed
      #
      def enq(executable, *_results)
        case
        when aggregate
          
          case
          when iterate, splat, stack
            raise "iterate, splat, or stack and aggregate"
          else collect(executable, _results)
          end
          
        else
          unpack(_results) do |_result|
            case
            when stack
              executable.enq(*_result)            
            else
              executable._execute(*_result)
            end
          end
        end
      end
      
      # returns the aggregator for self
      def aggregator # :nodoc:
        @aggregator ||= {}
      end
      
      # helper method to aggregate audited results
      def collect(executable, inputs) # :nodoc:
        queue = executable.app.queue
        round = aggregator[executable]
        
        queue.synchronize do
          unless queue.has_round?(round)
            round = aggregator[executable] = [[executable, []]]
            queue.concat(round)
            
            # dirty patch, see http://bahuvrihi.lighthouseapp.com/projects/9908-tap-task-application/tickets/174-bug-in-joinaggregate-logic
            queue.concat([])
          end
          round[0][1].concat(inputs)
        end
      end
      
      # helper method to splat/iterate audited results
      def unpack(_results) # :nodoc:
        case
        when iterate && splat
          raise "splat and iterate"
        when iterate
          _splat(_results).each {|_result| yield(_result) }
        when splat
          yield(_splat(_results))
        else
          yield(_results)
        end
      end
      
      # helper to splat audits
      def _splat(_results)  # :nodoc:
        array = []
        _results.each do |_result|
          unless _result.kind_of?(Audit)
            _result = Audit.new(nil, _result)
          end
          
          array.concat(_result.splat)
        end
        array
      end
    end
  end
end
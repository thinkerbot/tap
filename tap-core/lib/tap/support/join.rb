module Tap
  module Support
    
    # Joins create on_complete blocks which link together tasks (or more
    # generally, Executable objects) into workflows.  Joins support a 
    # variety of configurations which affect how one task passes inputs
    # to subsequent tasks.
    #
    # Joins have a single source and may have multiple targets.  See
    # ReverseJoin for joins with a single target and multiple sources.
    class Join
      class << self
        
        # Create a join between the source and targets.  Targets should
        # be an array; if the last member of targets is a hash, it will
        # be used as the configurations for the join.
        def join(source, targets, &block)
          options = targets[-1].kind_of?(Hash) ? targets.pop : {}
          new(options).join(source, targets, &block)
        end
      end
      
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
      
      # Causes joins to only occur between the
      # explicitly named source and targets,
      # and not their batches.
      config :unbatched, false, :short => 'u', &c.boolean
      
      # An array of workflow flags.  Workflow flags are false unless specified.
      FLAGS = configurations.keys
      
      # An array of the shorts corresponding to FLAGS. 
      SHORT_FLAGS = configurations.keys.collect {|key| configurations[key].attributes[:short] }
      
      # Initializes a new join with the specified configuration.
      def initialize(config)
        initialize_config(config)
      end
      
      # The name of the join, as a symbol.  By default name 
      # is the basename of the underscored class name.
      def name
        File.basename(self.class.to_s.underscore).to_sym
      end
      
      # Creates a join between the source and targets.
      # Must be implemented in subclasses.
      def join(source, targets, &block)
        raise NotImplementedError
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
      
      # Sets the on_complete block for the specified executable.
      # If unbatched == true, the on_complete block will only 
      # be set for the executable; otherwise the on_complete
      # block will be set for executable.batch.
      def complete(executable, &block)
        executable.send(unbatched ? :unbatched_on_complete : :on_complete, &block)
      end
      
      # Enques the executable with the results, respecting the
      # configuration for self.
      #
      #                true                       false
      #   iterate      _results are iterated      _results are enqued directly
      #   splat        _results are splat enqued  _results are enqued directly
      #   stack        the executable is enqued   the executable is executed
      #   unbatched    only exectuable is enqued  executable.batch is enqued
      #
      def enq(executable, *_results)
        unpack(_results) do |_result|
          if stack 
            if unbatched
              executable.unbatched_enq(*_result)
            else
              executable.enq(*_result)
            end
          else
            if unbatched
              executable._execute(*_result)
            else
              executable.batch.each do |e|
                e._execute(*_result)
              end
            end
          end
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
    
    # Like a Join, but with a single target and multiple sources.
    class ReverseJoin < Join
      class << self
        # Create a join between the sources and target.  Sources should
        # be an array; if the last member of sources is a hash, it will
        # be used as the configurations for the join.
        def join(target, sources, &block)
          options = sources[-1].kind_of?(Hash) ? sources.pop : {}
          new(options).join(target, sources, &block)
        end
      end
      
      # Creates a join between the sources and target.
      # Must be implemented in subclasses.
      def join(target, sources, &block)
        raise NotImplementedError
      end
      
      # Returns a string like: "#<ReverseJoin:object_id>"
      def inspect
        "#<ReverseJoin:#{object_id}>"
      end
    end
  end
end
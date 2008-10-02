module Tap
  module Support
    class Join
      class << self
        def join(source, targets, &block)
          options = targets[-1].kind_of?(Hash) ? targets.pop : {}
          new(options).join(source, targets, &block)
        end
      end
      
      include Configurable
      
      config :iterate, false, &c.boolean
      config :stack, false, &c.boolean
      config :unbatched, false, &c.boolean
      
      # An array of workflow flags.  All workflow flags are false unless specified.
      FLAGS = configurations.keys
      
      # An array of the first character in each WORKFLOW_FLAGS. 
      SHORT_FLAGS = FLAGS.collect {|flag| flag.to_s[0,1]}

      def initialize(options)
        initialize_config(options)
      end
      
      def name
        self.class.to_s =~ /.*::(.*)$/
        $1.underscore.to_sym
      end
      
      def options
        opts = config.to_hash
        opts.delete_if {|key, value| value == false }
        opts
      end
      
      def inspect
        "#<Join:#{object_id}>"
      end
      
      protected
      
      def complete(executable, &block)
        executable.send(unbatched ? :unbatched_on_complete : :on_complete, &block)
      end
      
      def enq(executable, _results)
        app = executable.app
        
        results = iterate ? _results._iterate : [_results]
        results.each do |_result|
          if stack 
      
            if unbatched
              executable.unbatched_enq(_result)
            else
              executable.enq(_result)
            end
      
          else
      
            if unbatched
              executable._execute(_result)
            else
              executable.batch.each do |e|
                e._execute(_result)
              end
            end
      
          end
        end
      end
    end
    
    class ReverseJoin < Join
      def join(target, sources, &block)
        options = sources[-1].kind_of?(Hash) ? sources.pop : {}
        new(options).join(target, sources, &block)
      end
      
      def inspect
        "#<ReverseJoin:#{object_id}>"
      end
    end
  end
end
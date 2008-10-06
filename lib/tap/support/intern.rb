module Tap
  module Support
    module Intern
    
      # A block called during process
      attr_accessor :process_block

      # By default process passes self and the input(s) to the block   
      # provided during initialization.  In this case the task block dictates  
      # the number of arguments enq should receive.  Simply returns the inputs
      # if no block is set.
      #
      #   # two arguments in addition to task are specified
      #   # so this Task must be enqued with two inputs...
      #   t = Task.new {|task, a, b| [b,a] }
      #   t.enq(1,2).enq(3,4)
      #   t.app.run
      #   t.app.results(t)         # => [[2,1], [4,3]]
      #
      def process(*inputs)
        raise "no process block set" unless process_block
        inputs.unshift(self)
      
        arity = process_block.arity
        n = inputs.length
        unless n == arity || (arity < 0 && (-1-n) <= arity) 
          raise ArgumentError.new("wrong number of arguments (#{n} for #{arity})")
        end
      
        process_block.call(*inputs)
      end
      
      # Creates a new batched object and adds the object to batch. The batched object 
      # will be a duplicate of the current object but with a new name and/or 
      # configurations.
      def initialize_batch_obj(*args)
        super(*args).extend Intern
      end
      
    end
  end
end
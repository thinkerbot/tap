require 'tap/app'
require 'tap/intern'

module Tap
  class App
    # Generates a join between the inputs and outputs.
    def join(inputs, outputs, config={}, klass=Join, &block)
      klass.new(config, self).join(inputs, outputs, &block)
    end
  end
  
  # :startdoc::join an unsyncrhonized, multi-way join
  #
  # Join defines an unsynchronized, multi-way join where n inputs send their
  # results to m outputs.  Flags can augment how the results are passed, in
  # particular for array results.
  #
  class Join < App::Api
    class << self
      
      # Instantiates a new join with the input arguments and overrides
      # call with the block.  The block will be called with the join
      # instance and result.
      #
      # Simply instantiates a new join if no block is given.
      def intern(config={}, app=Tap::App.instance, &block) # :yields: join, result
        instance = new(config, app)
        if block_given?
          instance.extend Intern(:call)
          instance.call_block = block
        end
        instance
      end
      
      def parse!(argv=ARGV, app=Tap::App.instance)
        parser = self.parser
        argv = parser.parse!(argv, :add_defaults => false)
        
        build({
          'config' => parser.nested_config,
          'inputs' => argv.shift,
          'outputs' => argv.shift
        }, app)
      end
      
      def build(spec={}, app=Tap::App.instance)
        inputs = resolve(spec['inputs']) do |var|
          app.get(var) or raise "missing join input: #{var}"
        end
        
        outputs = resolve(spec['outputs']) do |var|
          app.get(var) or raise "missing join output: #{var}"
        end
        
        new(spec['config'] || {}, app).join(inputs, outputs)
      end
      
      protected
      
      def resolve(refs) # :nodoc:
        refs = case refs
        when String then parse_indicies(refs)
        when nil then []
        else refs
        end
        
        refs.collect! do |var|
          if var.kind_of?(String)
            yield(var)
          else
            var
          end
        end
      end
      
      # parses an str along commas, and collects the indicies as integers
      def parse_indicies(str) # :nodoc:
        str.split(",").delete_if do |n|
          n.empty?
        end
      end
    end
    
    # Causes the outputs to be enqued rather than executed immediately.
    config :enq, false, :short => 'q', &c.flag      # Enque output nodes
    
    # Splats the result to the outputs, allowing a many-to-one join
    # from the perspective of the results.
    #
    #   # results: [1,2,3]
    #   # outputs: call(*inputs)
    #   app.execute(output, *result)
    #
    config :splat, false, :short => 's', &c.flag    # Splat results to outputs
    
    # Iterates the results to the outputs, allowing a many-to-one join
    # from the perspective of the results.  Non-array results are converted
    # to arrays using to_ary:
    #
    #   # results: [1,2,3]
    #   # outputs: call(input)
    #   result.to_ary.each {|r| app.execute(output, r) }
    #
    # Iterate may be combined with splat:
    #
    #   # results: [[1,2],3]
    #   # outputs: call(*inputs)
    #   result.to_ary.each {|r| app.execute(output, *r) }
    #
    config :iterate, false, :short => 'i', &c.flag  # Iterate results to outputs
    
    signal :join do |sig, (inputs, outputs)|
      app = sig.obj.app
      
      inputs = resolve(inputs) do |var|
        app.get(var) or raise "missing join input: #{var}"
      end
      
      outputs = resolve(outputs) do |var|
        app.get(var) or raise "missing join output: #{var}"
      end
      
      [inputs, outputs]
    end
    
    # An array of input nodes, or nil if the join has not been set.
    attr_reader :inputs
    
    # An array of output nodes, or nil if the join has not been set.
    attr_reader :outputs
    
    # Initializes a new join with the specified configuration.
    def initialize(config={}, app=Tap::App.instance)
      @inputs = nil
      @outputs = nil
      super
    end
    
    # Sets self as a join between the inputs and outputs.
    def join(inputs, outputs)
      @inputs.each do |input|
        input.joins.delete(self)
      end if @inputs
      
      @inputs = inputs
      
      inputs.each do |input|
        input.joins << self
      end if inputs
      
      @outputs = outputs
      self
    end
    
    # Executes the join logic for self, which by default passes the result to
    # each output.
    def call(result)
      outputs.each do |output|
        dispatch(output, result)
      end
    end
    
    def associations
      [inputs + outputs]
    end
    
    def to_spec
      spec = super
      spec['inputs'] = inputs.collect {|node| app.var(node) }
      spec['outputs'] = outputs.collect {|node| app.var(node) }
      spec
    end
    
    protected
    
    # Dispatches the results to the node.
    def dispatch(node, result) # :nodoc:
      mode = enq ? :enq : :execute
      if iterate
        result.to_ary.each {|r| execute(mode, node, r) }
      else
        execute(mode, node, result)
      end
    end
    
    # Executes the node with the input results.
    def execute(mode, node, result) # :nodoc:
      if splat
        app.send(mode, node, *result)
      else
        app.send(mode, node, result)
      end
    end
  end
end
require 'tap/app/api'

module Tap
  # :startdoc::join unsyncrhonized multi-way join
  #
  # Join defines an unsynchronized, multi-way join where n inputs send their
  # results to m outputs.  Flags can augment how the results are passed, in
  # particular for array results.
  #
  class Join < App::Api
    class << self
      def build(spec={}, app=Tap::App.current)
        inputs = resolve(spec['inputs']) do |var|
          app.get(var) or raise "missing join input: #{var}"
        end
        
        outputs = resolve(spec['outputs']) do |var|
          app.get(var) or raise "missing join output: #{var}"
        end
        
        new(spec['config'] || {}, app).join(inputs, outputs)
      end
      
      protected
      
      def convert_to_spec(parser, args)
        {
          'config' => parser.nested_config,
          'inputs' => args.shift,
          'outputs' => args.shift
        }
      end
      
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
    config :enq, false, :short => 'q', &c.flag      # Enque output tasks
    
    # Converts each result into a one-member array before being passed onto
    # outputs. Arrayify occurs before iterate and combined the two flags
    # cancel.
    config :arrayify, false, :short => 'a', &c.flag # Arrayify results
    
    # Iterates the results to the outputs.  Non-array results are converted to
    # arrays using to_ary:
    #
    #   # results: [1,2,3]
    #   # outputs: call(input)
    #   result.to_ary.each {|r| app.exe(output, r) }
    #
    config :iterate, false, :short => 'i', &c.flag  # Iterate results to outputs
    
    signal :join do |sig, (inputs, outputs)|        # join app objects
      app = sig.obj.app
      
      inputs = resolve(inputs) do |var|
        app.get(var) or raise "missing join input: #{var}"
      end
      
      outputs = resolve(outputs) do |var|
        app.get(var) or raise "missing join output: #{var}"
      end
      
      [inputs, outputs]
    end
    
    # An array of input tasks, or nil if the join has not been set.
    attr_reader :inputs
    
    # An array of output tasks, or nil if the join has not been set.
    attr_reader :outputs
    
    # Initializes a new join with the specified configuration.
    def initialize(config={}, app=Tap::App.current)
      @inputs = nil
      @outputs = nil
      super
    end
    
    # Sets self as a join between the inputs and outputs.
    def join(inputs, outputs)
      @inputs.each do |input|
        input.joins.delete(self)
      end if @inputs
      
      inputs.each do |input|
        unless input.respond_to?(:joins)
          raise "input does not support joins: #{input.inspect}"
        end
      end
      
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
        exe(output, result)
      end
    end
    
    def associations
      [inputs + outputs]
    end
    
    def to_spec
      spec = super
      spec['inputs'] = inputs.collect {|task| app.var(task) }
      spec['outputs'] = outputs.collect {|task| app.var(task) }
      spec
    end
    
    protected
    
    # Executes the task with the input results.
    def exe(task, result) # :nodoc:
      mode = enq ? :enq : :exe
      
      if arrayify
        result = [result]
      end
      
      if iterate
        result.to_ary.each {|item| app.send(mode, task, item) }
      else
        app.send(mode, task, result)
      end
    end
  end
end
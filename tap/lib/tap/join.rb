module Tap
  class App
    def join(inputs, outputs, config={}, klass=Join, &block)
      klass.new(config, self).join(inputs, outputs, &block)
    end
  end
  
  # ::join simple join
  class Join
    class << self
      def parse(argv=ARGV, app=Tap::App.instance)
        parse!(argv.dup, app)
      end
      
      def parse!(argv=ARGV, app=Tap::App.instance)
        opts = ConfigParser.new
        opts.separator "configurations:"
        opts.add(configurations)
        args = opts.parse!(argv, {}, false)
        
        instantiate({:config => opts.nested_config, :args => args}, app)
      end
      
      def instantiate(argh, app=Tap::App.instance)
        new(argh[:config] || {}, app)
      end
      
      def intern(config={}, app=Tap::App.instance, &block) # :yields: join, result
        instance = new(config, app)
        if block_given?
          instance.extend Support::Intern(:call)
          instance.call_block = block
        end
        instance
      end
      
      # Parses a modifier string into configurations.  Raises an error
      # if the options string contains unknown options.
      #
      #   parse_modifier("")                   # => {}
      #   parse_modifier("iq")                 # => {:iterate => true, :enq => true}
      #
      def parse_modifier(str)
        return {} unless str
        
        options = {}
        0.upto(str.length - 1) do |char_index|
          char = str[char_index, 1]

          entry = configurations.find do |key, config| 
            config.attributes[:short] == char
          end
          key, config = entry

          raise "unknown option in: #{str} (#{char})" unless key 
          options[key] = true
        end
        options
      end
    end
    include Configurable
    
    lazy_attr :desc, 'join'
    
    # Causes the targets to be enqued rather than executed immediately.
    config :enq, false, :short => 'q', &c.flag
    
    # Splats the result to the outputs, allowing a many-to-one join
    # from the perspective of the results.
    #
    #   # results: [1,2,3]
    #   # outputs: call(*inputs)
    #   app.execute(output, *result)
    #
    config :splat, false, :short => 's', &c.flag
    
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
    config :iterate, false, :short => 'i', &c.flag
    
    # The App receiving self during enq
    attr_accessor :app
    
    # An array of input nodes, or nil if the join has not been set.
    attr_reader :inputs
    
    # An array of output nodes, or nil if the join has not been set.
    attr_reader :outputs
    
    # Initializes a new join with the specified configuration.
    def initialize(config={}, app=Tap::App.instance)
      @app = app
      @inputs = nil
      @outputs = nil
      initialize_config(config)
    end
    
    # Sets self as a join between the inputs and outputs.
    def join(inputs, outputs)
      @inputs.each do |input|
        input.join = nil
      end if @inputs
      
      @inputs = inputs
      
      inputs.each do |input|
        input.join = self
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
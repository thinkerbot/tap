module Tap
  
  # ::join
  class Join
    class << self
      def parse(argv=ARGV)
        parse!(argv.dup)
      end
      
      def parse!(argv=ARGV)
        instantiate :config => parse_modifier(argv.shift)
      end
      
      def instantiate(argh)
        new(argh[:config] || {})
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
    
    # Causes the targets to be enqued rather than executed immediately.
    config :enq, false, :short => 'q', &c.flag
    
    # Splats the results of each input before execution, allowing a
    # many-to-one join from the perspective of the results. If inputs
    # [A,B,C] produce results [a,b,c], the outputs will be executed like:
    #
    #   app.execute(output, *a, *b, *c)
    #
    # Note splat is applied before iterate.
    config :splat, false, :short => 's', &c.flag
    
    # Iterates each result, allowing a one-to-many or many-to-many
    # join from the perspective of the results.  Like splat, iterate works
    # at the level of input.  If inputs [A,B,C] produce results [a,b,c],
    # the outputs will be executed like:
    #
    #   app.execute(output, a)
    #   app.execute(output, b)
    #   app.execute(output, c)
    #
    # Splat and iterate may be combined to iterate over each value of each
    # result:
    #
    #   a.each {|r| app.execute(output, r) }
    #   b.each {|r| app.execute(output, r) }
    #   c.each {|r| app.execute(output, r) }
    #
    # In this case, non-array results are either converted to arrays using
    # to_ary, or treated like single-member arrays.  For instance if
    # [a,b,c] are [1, [2,3,[4,5]], 6]:
    #
    #  [1].each {|r| ... }
    #  [2,3,[4,5]].each {|r| ... }
    #  [6].each {|r| ... }
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
      @inputs = inputs.each do |input|
        input.join = self
      end
      @outputs = outputs
      self
    end
    
    # Executes the join logic for self, which by default passes the result to
    # each output.
    def call(result)
      outputs.each do |output|
        execute(output, result)
      end
    end
    
    # Returns a string like: "#<Join:object_id>"
    def inspect
      "#<Join:#{object_id}>"
    end
    
    protected
    
    # Executes the node with the input results.
    def execute(node, *results)
      if splat
        results = splat!(results)
      end
      
      mode = enq ? :enq : :execute
      
      if iterate
        results.each {|result| app.send(mode, node, result) }
      else
        app.send(mode, node, *results)
      end
    end
    
    # Performs a splat operation on results, essentially this:
    #
    #   [*results[0], *results[1], ..., *results[-1]]
    #
    def splat!(results) # :nodoc:
      array = []
      results.each do |result|
        if result.respond_to?(:to_ary)
          array.concat(result.to_ary)
        else
          array << result
        end
      end
      array
    end

  end
end
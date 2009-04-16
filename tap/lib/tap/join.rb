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
      #   parse_modifier("is")                 # => {:iterate => true, :splat => true}
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

    # Causes the join to iterate the results
    # of the source when enquing the targets.
    config :iterate, false, :short => 'i', &c.flag

    # Causes joins to splat ('*') the results
    # of the source when enquing the targets.
    config :splat, false, :short => 's', &c.flag

    # Causes the targets to be enqued rather
    # than executed immediately.
    config :stack, false, :short => 'k', &c.flag
    
    # The App receiving self during enq
    attr_accessor :app
    
    attr_reader :inputs
    
    attr_reader :outputs
    
    # Initializes a new join with the specified configuration.
    def initialize(config={}, app=Tap::App.instance)
      @app = app
      @inputs = nil
      @outputs = nil
      initialize_config(config)
    end
    
    # The name of the join, as a symbol.  By default name is the basename of
    # the underscored class name.
    def name
      File.basename(self.class.to_s.underscore).to_sym
    end
    
    # Creates a join that passes the results of each input to each output.
    def join(inputs, outputs)
      @inputs = inputs.each do |input|
        input.join = self
      end
      @outputs = outputs
      self
    end
    
    def call(result)
      outputs.each do |output|
        enq(output, result)
      end
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
    def enq(node, *results)
      if splat
        results = splat!(results)
      end
      
      mode = stack ? :enq : :execute
      
      if iterate
        results.each {|result| app.send(mode, node, result) }
      else
        app.send(mode, node, *results)
      end
    end
    
    def splat!(results)
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
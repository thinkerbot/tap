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
      #   parse_modifier("iq")                 # => {:modifier => :iterate, :mode => :enq}
      #
      def parse_modifier(str)
        return {} unless str
        
        options = {}
        0.upto(str.length - 1) do |char_index|
          case char = str[char_index, 1]
          when 'i' 
            options[:modifier] = :iterate
          when 's' 
            options[:modifier] = :splat
          when 'q' 
            options[:mode] = :enq
          when 'a' 
            options[:mode] = :aggregate
          when 'c' 
            options[:mode] = :collect
          when 'e' 
            options[:mode] = :execute
          else 
            raise "unknown option in: #{str} (#{char})"
          end
        end
        options
      end
    end
    
    include Configurable
    
    config :mode, :execute, &c.select(:execute, :enq, :aggregate, :collect)
    config :modifier, :none, &c.select(:none, :iterate, :splat)
    
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
    def enq(node, result)
      case mode
      when :aggregate
        aggregate(node) do |results|
          results << result
        end
        
      when :collect
        aggregate(node) do |results|
          results.concat [*result]
        end
        
      when :execute
        case modifier
        when :iterate
          result.each {|r| app.execute(node, [r]) }
        when :splat
          app.execute(node, [*result])
        else
          app.execute(node, [result])
        end
        
      when :enq
        case modifier
        when :iterate
          result.each {|r| app.enq(node, r) }
        when :splat
          app.enq(node, *result)
        else
          app.enq(node, result)
        end
        
      end
    end
    
    # returns the aggregator for self
    def aggregator # :nodoc:
      @aggregator ||= {}
    end
    
    # helper method to aggregate audited results
    def aggregate(node) # :nodoc:
      queue = app.queue
      entry = aggregator[node]
      
      queue.synchronize do
        unless queue.has?(entry)
          entry = aggregator[node] = [node, []]
          queue.concat [entry]
        end
        yield(entry[1])
      end
    end
  end
end
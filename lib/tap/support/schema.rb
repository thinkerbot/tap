require 'tap/support/node'

module Tap
  module Support
    class Schema
      class << self  
        # Shell quotes the input string by enclosing in quotes if
        # str has no quotes, or double quotes if str has no double
        # quotes.  Returns the str if it has not whitespace, quotes
        # or double quotes.
        #
        # Raises an ArgumentError if str has both quotes and double
        # quotes.
        def shell_quote(str)
          return str unless str =~ /[\s'"]/

          quote = str.include?("'")
          double_quote = str.include?('"')

          case
          when !quote then "'#{str}'"
          when !double_quote then "\"#{str}\""
          else raise ArgumentError, "cannot shell quote: #{str}"
          end
        end
        
        def load(task_argv)
          task_argv = YAML.load(task_argv) if task_argv.kind_of?(String)

          tasks, argv = task_argv.partition {|obj| obj.kind_of?(Array) }
          parser = new
          parser.tasks.concat(tasks)
          parser.parse(argv)
          parser
        end
      end
      
      # An array of the nodes registered in self.
      attr_reader :nodes

      def initialize(nodes=[])
        @nodes = nodes
      end
      
      # Retrieves the node at index, or instantiates
      # a new Node if one does not already exists.
      def [](index)
        nodes[index] ||= Node.new
      end
      
      # Sets a join between the source and targets.  
      # Returns the new join.
      def set(type, options, source_index, target_indicies)
        join = Node::Join.new(type, options)
        
        [*target_indicies].each {|target_index| self[target_index].input = join  }
        self[source_index].output = join
        
        join
      end
      
      # Sets a reverse join between the sources and target.  
      # Returns the new join.
      def set_reverse(type, options, source_indicies, target_index)
        join = Node::ReverseJoin.new(type, options)
        
        self[target_index].output = join
        [*source_indicies].each {|source_index| self[source_index].input = join }
        
        join
      end
      
      # Removes all nil nodes, and nodes with empty argvs.
      # Additionally reassigns rounds by shifting later
      # rounds up to fill any nils in the rounds array.
      #
      # Returns self.
      def compact
        # remove nil and empty nodes
        nodes.delete_if do |node|
          node == nil || node.argv.empty?
        end
        
        # reassign rounds
        index = 0
        rounds.compact.each do |round|
          round.each {|node| node.round = index }
          index += 1
        end
        
        self
      end
      
      # Returns an array of the argvs for each nodes.
      def argvs
        nodes.collect do |node|
          node == nil ? nil : node.argv
        end
      end
      
      # Returns a collection of nodes sorted  
      # into arrays by node.round.
      def rounds
        rounds = []
        nodes.each do |node|
          (rounds[node.round] ||= []) << node if node && node.round
        end
        rounds
      end
      
      # Returns a collection of global nodes
      # (nodes with no input or output set).
      def globals
        globals = []
        nodes.each do |node|
          globals << node if node && node.global?
        end
        globals
      end
      
      # Returns a hash of [join, [input_nodes, output_nodes]] pairs
      # across all nodes.
      def join_hash
        joins = {}
        nodes.each do |node|
          next unless node
          
          case node.input
          when Node::Join, Node::ReverseJoin
            (joins[node.input] ||= [nil,[]])[1] << node
          end
          
          case node.output
          when Node::Join, Node::ReverseJoin
            (joins[node.output] ||= [nil,[]])[0] = node
          end
        end

        joins
      end

      def build(app)
        tasks = {}
        
        # instantiate the nodes
        nodes.each do |node|
          tasks[node] = yield(node.argv) if node
        end
        
        # instantiate and reconfigure globals
        globals.each do |node|
          task, args = tasks[node]
          task.class.instance.reconfigure(task.config.to_hash)
        end

        # build the workflow
        join_hash.each_pair do |join, (source_node, target_nodes)|
          targets = target_nodes.collect do |target_node|
            tasks[target_node][0]
          end
          targets << join.options
          tasks[source_node][0].send(join.type, *targets)
        end

        # build queues
        queues = rounds.compact.collect do |round|
          round.each do |node|
            task, args = tasks.delete(node)
            task.enq(*args)
          end

          app.queue.clear
        end
        
        # notify any args that will be overlooked
        tasks.each_pair do |node, (task, args)|
          next if args.empty?
          puts "ignoring args: #{task} [#{args.join(' ')}]"
        end

        queues
      end
      
      # Creates an array dump of the contents of self.
      def dump
        segments = argvs
        each_schema_str {|str| segments << str }
        segments
      end
      
      # Constructs a command-line string for the schema, ex:
      # '-- a -- b --0:1'.
      def to_s
        segments = []
        nodes.each do |node|
          segments << "--"
          
          node.argv.each do |arg| 
            segments << Schema.shell_quote(arg)
          end unless node == nil
        end
        
        each_schema_str {|str| segments << "--#{str}" }
        segments.join(' ')
      end

      protected
      
      # Yields each formatted schema string (global, round, and join).
      def each_schema_str # :nodoc:
        each_globals_str {|str| yield str }
        each_round_str   {|str| yield str }
        each_join_str    {|str| yield str }
      end
      
      # Yields globals formatted as a string.
      def each_globals_str # :nodoc:
        globals.each do |node|
          yield "*#{nodes.index(node)}"
        end
      end
      
      # Yields each round formatted as a string.
      def each_round_str # :nodoc
        index = 0
        rounds.each do |indicies|
          unless indicies == nil || index == 0
            indicies = indicies.collect {|node| nodes.index(node) }
            yield "+#{index}[#{indicies.join(',')}]"
          end
          index += 1
        end
      end

      # Yields each join formatted as a string.
      def each_join_str # :nodoc
        join_hash.each_pair do |join, (source_node, target_nodes)|
          source_index = nodes.index(source_node)
          target_indicies = target_nodes.collect {|node| nodes.index(node) }
          
          yield case join.type
          when :sequence   then ([source_index] + target_indicies).join(":")
          when :fork       then "#{source_index}[#{target_indicies.join(',')}]"
          when :merge      then "#{source_index}{#{target_indicies.join(',')}}"
          when :sync_merge then "#{source_index}(#{target_indicies.join(',')})"
          else raise "unknown join type: #{join.type} (#{source_index}, [#{target_indicies.join(',')}])"
          end
        end
      end
    end
  end
end
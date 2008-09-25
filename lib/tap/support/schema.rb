require 'tap/support/node'
autoload(:Shellwords, 'shellwords')

module Tap
  module Support
    autoload(:Parser, 'tap/support/parser')
    
    class Schema
      module Utils
        module_function
        
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
        
        # Formats a round string.
        #
        #   format_round(1, [1,2,3])            # => "+1[1,2,3]"
        #
        def format_round(round, indicies)
          "+#{round}[#{indicies.join(',')}]"
        end

        # Formats a sequence string.
        #
        #   format_sequence(1, [2,3], {})       # => "1:2:3"
        #
        def format_sequence(source_index, target_indicies, options)
          ([source_index] + target_indicies).join(":") + format_options(options)
        end

        # Formats a global instance string.
        #
        #   format_instance(1)                  # => "*1"
        #
        def format_instance(index)
          "*#{index}"
        end

        # Formats a fork string.
        #
        #   format_fork(1, [2,3],{})            # => "1[2,3]"
        #
        def format_fork(source_index, target_indicies, options)
          "#{source_index}[#{target_indicies.join(',')}]#{format_options(options)}"
        end

        # Formats a merge string (note the target index is
        # provided first).
        #
        #   format_merge(1, [2,3],{})           # => "1{2,3}"
        #
        def format_merge(target_index, source_indicies, options)
          "#{target_index}{#{source_indicies.join(',')}}#{format_options(options)}"
        end

        # Formats a sync_merge string (note the target index 
        # is provided first).
        #
        #   format_sync_merge(1, [2,3],{})      # => "1(2,3)"
        #
        def format_sync_merge(target_index, source_indicies, options)
          "#{target_index}(#{source_indicies.join(',')})#{format_options(options)}"
        end

        # Formats an options hash into a string.  Raises an error
        # for unknown options.
        #
        #   format_options({:iterate => true})  # => "i"
        #
        def format_options(options)
          options_str = []
          options.each_pair do |key, value|
            unless index = Executable::WORKFLOW_FLAGS.index(key)
              raise "unknown key in: #{options} (#{key})"
            end
            
            if value
              options_str << Executable::SHORT_WORKFLOW_FLAGS[index]
            end
          end
          options_str.sort.join
        end
      end
      
      include Utils
      
      class << self
        def parse(argv=ARGV)
          Support::Parser.new(argv).schema
        end

        def load(argv)
          parser = Parser.new
          parser.load(argv)
          parser.schema
        end

        def load_file(path)
          argv = YAML.load_file(path)
          load(argv)
        end
      end
      
      # An array of the nodes registered in self.
      attr_reader :nodes

      def initialize(nodes=[])
        @nodes = nodes
        @current_index = 1
      end
      
      # Retrieves the node at index, or instantiates
      # a new Node if one does not already exists.
      def [](index)
        nodes[index] ||= Node.new
      end
      
      # Sets a join between the source and targets.  
      # Returns the new join.
      def set(type, source_index, target_indicies, options={})
        join = Node::Join.new(type, options)
        
        [*target_indicies].each {|target_index| self[target_index].input = join  }
        self[source_index].output = join
        
        join
      end
      
      # Sets a reverse join between the sources and target.  
      # Returns the new join.
      def set_reverse(type, target_index, source_indicies, options={})
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
      def rounds(as_indicies=false)
        rounds = []
        nodes.each do |node|
          (rounds[node.round] ||= []) << node if node && node.round
        end
        
        rounds.each do |round|
          next unless round
          round.collect! {|node| nodes.index(node) }
        end if as_indicies

        rounds
      end
      
      # Returns a collection of global nodes
      # (nodes with no input or output set).
      def globals(as_indicies=false)
        globals = []
        nodes.each do |node|
          globals << node if node && node.global?
        end
        
        globals.collect! do |node| 
          nodes.index(node)
        end if as_indicies
        
        globals
      end
      
      # Returns a hash of [join, [source_node, target_nodes]] pairs
      # across all nodes.
      def joins(as_indicies=false)
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
        
        if as_indicies
          summary = []
          joins.each_pair do |join, (source_node, target_nodes)|
            target_indicies = target_nodes.collect {|node| nodes.index(node) }
            summary << [join.type, nodes.index(source_node), target_indicies, join.options]
          end
          
          summary.sort_by {|entry| entry[1] || -1 }
        else
          joins
        end
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
        joins.each_pair do |join, (source_node, target_nodes)|
          raise "unassigned join: #{join}" if source_node == nil

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
          warn "warning: ignoring args for node (#{nodes.index(node)}) #{task} [#{args.join(' ')}]"
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
            segments << shell_quote(arg)
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
          yield format_instance(nodes.index(node))
        end
      end
      
      # Yields each round formatted as a string.
      def each_round_str # :nodoc
        index = 0
        rounds.each do |indicies|
          unless indicies == nil || index == 0
            indicies = indicies.collect {|node| nodes.index(node) }
            yield format_round(index, indicies)
          end
          index += 1
        end
      end

      # Yields each join formatted as a string.
      def each_join_str # :nodoc
        joins.each_pair do |join, (source_node, target_nodes)|
          source_index = nodes.index(source_node)
          target_indicies = target_nodes.collect {|node| nodes.index(node) }
          
          yield case join.type
          when :sequence   then format_sequence(source_index, target_indicies, join.options)
          when :fork       then format_fork(source_index, target_indicies, join.options)
          when :merge      then format_merge(source_index, target_indicies, join.options)
          when :sync_merge then format_sync_merge(source_index, target_indicies, join.options)
          else raise "unknown join type: #{join.type} (#{source_index}, [#{target_indicies.join(',')}])"
          end
        end
      end
    end
  end
end
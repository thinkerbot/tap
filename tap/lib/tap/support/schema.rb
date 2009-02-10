require 'tap/support/node'
require 'tap/support/joins'
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
            unless config = Join.configurations[key]
              raise "unknown key in: #{options} (#{key})"
            end
            
            if value
              options_str << config.attributes[:short]
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
        
        # Loads a schema from the specified path.  Raises an error if no such
        # file existts.
        def load_file(path)
          argv = YAML.load_file(path)
          argv ? load(argv) : new
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
      def set(join_class, source_indicies, target_indicies, options={})
        join = join_class.new(options)

        [*source_indicies].each {|source_index| self[source_index].output = join }
        [*target_indicies].each {|target_index| self[target_index].input = join  }

        join
      end
      
      # Removes all nil nodes, nodes with empty argvs, and orphaned joins.
      # Additionally reassigns rounds by shifting later rounds up to fill
      # any nils in the rounds array.
      #
      # Returns self.
      def compact
        # remove nil and empty nodes
        nodes.delete_if do |node|
          node == nil || node.argv.empty?
        end
        
        # cleanup joins
        joins.each_pair do |join, (source_nodes, target_nodes)|
          source_nodes.each do |source_node|
            source_node.output = nil
          end if target_nodes.empty?
          
          target_nodes.each do |target_node|
            target_node.input = nil
          end if source_nodes.empty?
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
          
          output = node.output
          (joins[output] ||= [[],[]])[0] << node if output.kind_of?(Join)
          
          input = node.input
          (joins[input] ||= [[],[]])[1] << node if input.kind_of?(Join)
        end
        
        if as_indicies
          array = []
          joins.each_pair do |join, (source_nodes, target_nodes)|
            array << [join.name, node_indicies(source_nodes), node_indicies(target_nodes), join.options]
          end
          
          array.sort_by {|entry| entry[1] || -1 }
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
        instances = []
        globals.each do |node|
          task, args = tasks.delete(node)
          instance = task.class.instance
          
          if instances.include?(instance)
            raise "global specified multple times: #{instance}"
          end
          
          instance.reconfigure(task.config.to_hash)
          instance.enq(*args)
          instances << instance
        end

        # build the workflow
        joins.each_pair do |join, (source_nodes, target_nodes)|
          raise "orphan join: #{join}" if source_nodes.empty? || target_nodes.empty?
          
          sources = source_nodes.collect do |source_node|
            tasks[source_node][0]
          end
          targets = target_nodes.collect do |target_node|
            tasks[target_node][0]
          end
          
          join.join(source, targets)
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
      
      def node_indicies(node_array) # :nodoc:
        node_array.collect {|node| nodes.index(node) }
      end
      
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
        joins.each_pair do |join, (source_nodes, target_nodes)|
          source_indicies = node_indicies(source_nodes)
          target_indicies = node_indicies(target_nodes)

          yield case join
          when Joins::Sequence   then format_sequence(source_indicies, target_indicies, join.options)
          when Joins::Fork       then format_fork(source_indicies, target_indicies, join.options)
          when Joins::Merge      then format_merge(target_indicies, source_indicies, join.options)
          when Joins::SyncMerge  then format_sync_merge(target_indicies, source_indicies, join.options)
          else raise "unknown join type: #{join.class} ([#{source_indicies.join(',')}], [#{target_indicies.join(',')}])"
          end
        end
      end
    end
  end
end
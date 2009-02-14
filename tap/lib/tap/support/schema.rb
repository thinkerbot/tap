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
        def format_sequence(source_index, outputs, options)
          ([source_index] + outputs).join(":") + format_options(options)
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
        def format_fork(source_index, outputs, options)
          "#{source_index}[#{outputs.join(',')}]#{format_options(options)}"
        end

        # Formats a merge string (note the target index is
        # provided first).
        #
        #   format_merge(1, [2,3],{})           # => "1{2,3}"
        #
        def format_merge(target_index, inputs, options)
          "#{target_index}{#{inputs.join(',')}}#{format_options(options)}"
        end

        # Formats a sync_merge string (note the target index 
        # is provided first).
        #
        #   format_sync_merge(1, [2,3],{})      # => "1(2,3)"
        #
        def format_sync_merge(target_index, inputs, options)
          "#{target_index}(#{inputs.join(',')})#{format_options(options)}"
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
      
      # Retrieves the node at index, or instantiates a new Node if one does
      # not already exists.
      def [](index)
        nodes[index] ||= Node.new
      end
      
      # Returns the index of the node in nodes.
      def index(node)
        nodes.index(node)
      end
      
      # Shortcut to collect the indicies of each node in nodes.  Returns nil if
      # nodes is nil.
      def indicies(nodes)
        nodes ? nodes.collect {|node| index(node) } : nodes
      end
       
      # Returns an array of the argvs for each nodes.
      def argvs
        nodes.collect do |node|
          node == nil ? nil : node.argv
        end
      end
      
      # Returns a collection of nodes sorted into arrays by round.
      def rounds
        rounds = []
        nodes.each do |node|
          next unless node
          round = node.round
          (rounds[round] ||= []) << node if round
        end
        rounds
      end
      
      # Returns a collection of global nodes.
      def globals
        globals = []
        nodes.each do |node|
          if node && node.global?
            globals << node
          end
        end
        globals
      end
      
      # Returns an array of joins among nodes in self.
      def joins
        joins = []
        
        nodes.each do |node|
          next unless node
          if join = node.output_join
            joins << join
          end
        end
        
        nodes.each do |node|
          next unless node
          if join = node.input_join
            joins << join
          end
        end
        
        joins.uniq
      end
      
      # Sets a join between the nodes at the input and output indicies.
      # Returns the new join.
      def set(join_class, inputs, outputs, options={})
        unless inputs && !inputs.empty?
          raise ArgumentError, "no input nodes specified"
        end
        
        join = [join_class.new(options), [],[]]
        
        inputs.each {|index| self[index].output = join }
        outputs.each {|index| self[index].input = join }
        
        join
      end
      
      # Removes all nil nodes, nodes with empty argvs, and orphaned joins.
      # Additionally reassigns rounds by shifting later rounds up to fill
      # any nils in the rounds array.
      #
      # Returns self.
      #
      #-- 
      # Note: the algorithm for cleaning up joins can likely be optimized.
      def cleanup
        # remove nil and empty nodes
        nodes.delete_if do |node|
          node == nil || node.argv.empty?
        end
        
        # cleanup joins
        joins.each do |join, input_nodes, output_nodes|
          
          # remove missing output nodes
          output_nodes.delete_if {|node| !nodes.include?(node) }

          # remove missing input nodes; the removed nodes need
          # to be preserved in case an orphan join results and
          # the natural round before cleanup needs to be
          # determined.
          remaining_nodes, removed_nodes = input_nodes.partition {|node| nodes.include?(node) }
          
          case
          when remaining_nodes.empty?
            # orphan join: reassign output nodes to natural round
            orphan_round = Node.natural_round(removed_nodes)
            output_nodes.dup.each {|node| node.round = orphan_round }
          else
            input_nodes.replace(remaining_nodes)
          end
        end
        
        # reassign rounds
        index = 0
        rounds.compact.each do |round|
          round.each {|node| node.round = index }
          index += 1
        end
        
        self
      end
      
      def build(app)
        cleanup
        
        # instantiate the nodes
        tasks = {}
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
        joins.each do |join, input_nodes, output_nodes|
          sources = input_nodes.collect {|node| tasks[node][0] }
          targets = output_nodes.collect {|node| tasks[node][0] }
          
          join.join(sources, targets)
        end

        # build rounds
        queues = rounds.compact.collect do |round|
          round.collect {|node| tasks.delete(node) }
        end
        
        # notify any args that will be overlooked
        tasks.each_pair do |node, (task, args)|
          next if args.empty?
          warn "warning: ignoring args for node (#{index(node)}) #{task} [#{args.join(' ')}]"
        end
        
        # enque
        queues.each {|queue| app.queue.concat(queue) }
        app
      end
      
      # Creates an array dump of the contents of self.
      def dump
        cleanup
        
        # add argvs
        array = argvs
        
        # add global declarations
        globals.each do |node|
          array << format_instance(index(node))
        end
        
        # add round declarations
        index = 0
        rounds.each do |nodes|
          
          # skip round 0 as it is implicit
          if index > 0
            indicies = nodes.collect {|node| index(node) }
            array << format_round(index, indicies)
          end
          
          index += 1
        end
        
        # add join declarations
        joins.each do |join, input_nodes, output_nodes|
          inputs = input_nodes.collect {|node| nodes.index(node) }
          outputs = output_nodes.collect {|node| nodes.index(node) }

          array << case join
          when Joins::SyncMerge  then format_sync_merge(outputs, inputs, join.options)
          when Join
            if inputs.length == 1
              if outputs.length == 1
                format_sequence(inputs, outputs, join.options)
              else
                format_fork(inputs, outputs, join.options)
              end
            else
              format_merge(outputs, inputs, join.options)
            end
          else raise "unknown join type: #{join.class} ([#{inputs.join(',')}], [#{outputs.join(',')}])"
          end
        end
        
        array
      end
      
      # Constructs a command-line string for the schema, ex:
      # '-- a -- b --0:1'.
      def to_s
        args = []
        dump.each do |obj|
          if obj.kind_of?(Array)
            args << "--"
            args.concat obj.collect {|arg| shell_quote(arg) }
          else
            args << "--#{obj}"
          end
        end
        
        args.join(' ')
      end
      
    end
  end
end
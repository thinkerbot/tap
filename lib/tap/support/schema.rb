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
      
      attr_reader :nodes

      def initialize(nodes=[])
        @nodes = nodes
      end
      
      # Retrieves the node at index, or instantiates a new Node
      # if no such node exists.
      def [](index)
        nodes[index] ||= Node.new
      end
      
      # Returns an array of the argvs across all nodes.  Nil and
      # empty argvs are removed.
      def argvs
        nodes.collect do |node|
          node == nil ? nil : node.argv
        end
      end
      
      # Returns a collection of nodes sorted into 
      # arrays by node.round.
      def rounds
        rounds = []
        nodes.each_index do |index|
          next unless node = nodes[index]
          (rounds[node.round] ||= []) << index if node.round
        end
        rounds
      end
      
      # Returns a collection of global nodes.
      def globals
        globals = []
        nodes.each_index do |index|
          node = nodes[index]
          globals << index if node && node.global?
        end
        globals
      end
      
      def joins
        joins = {}
        nodes.each_index do |index|
          next unless node = nodes[index]
          
          if node.input.kind_of?(Node::Join)
            (joins[node.input] ||= [[],[]])[1] << index
          end
          
          if node.output.kind_of?(Node::Join)
            (joins[node.output] ||= [[],[]])[0] << index
          end
        end

        joins
      end
      
      # def to_s
      #   segments = []
      #   nodes.each do |node|
      #     next if node == nil
      # 
      #     segments << case node.round
      #     when 0 then "--"
      #     when 1 then "--+"
      #     when nil then nil
      #     else "--+#{node.round}"
      #     end
      #     
      #     segments.concat(node.argv.collect {|arg| Schema.shell_quote(arg) })
      #   end
      # 
      #   each_join_str {|str| segments << "--#{str}" }
      #   segments.join(' ')
      # end
      
      # Sets the targets to the source in workflow_map, tracking the
      # workflow type.
      def set(type, options, source_index, target_indicies) # :nodoc
        join = Node::Join.new(type, options)
        
        [*target_indicies].each {|target_index| self[target_index].input = join }
        self[source_index].output = join
      end

      def dump
        segments = tasks.dup
        each_round_str {|str| segments << str }
        each_workflow_str {|str| segments << str }

        segments
      end

      def build(app)
        instances = []

        # instantiate and assign globals
        globals.each do |index|
          task, args = yield(nodes[index].argv)
          task.class.instance = task
          instances[index] = [task, args]
        end

        # instantiate the remaining task classes
        tasks.each_with_index do |args, index|
          instances[index] ||= yield(args)
        end

        # build the workflow
        workflow.each_with_index do |(type, target_indicies, options), source_index|
          next if type == nil

          targets = if target_indicies.kind_of?(Array)
            target_indicies.collect {|i| instances[i][0] }
          else
            instances[target_indicies][0]
          end
          #targets << options

          instances[source_index][0].send(type, *targets)
        end

        # build queues
        queues = rounds.collect do |round|
          round.each do |index|
            task, args = instances[index]
            instances[index] = nil
            task.enq(*args)
          end

          app.queue.clear
        end
        queues.delete_if {|queue| queue.empty? }

        # notify any args that will be overlooked
        instances.compact.each do |(instance, args)|
          next if args.empty?
          puts "ignoring args: #{instance} [#{args.join(' ')}]"
        end

        queues
      end

      protected

      # Yields each round formatted as a string.
      def each_round_str # :nodoc
        index = 0
        rounds.each do |indicies|
          yield "+#{index}[#{indicies.join(',')}]" unless indicies == nil
          index += 1
        end
      end

      # Yields each workflow element formatted as a string.
      def each_join_str # :nodoc
        joins.each_pair do |join, (inputs, outputs)| 
          yield case join.type
          when :sequence   then (inputs + outputs).join(":")
          when :fork       then "#{inputs[0]}[#{outputs.join(',')}]"
          when :merge      then "#{outputs[0]}{#{inputs.join(',')}}"
          when :sync_merge then "#{outputs[0]}(#{inputs.join(',')})"
          end
        end
      end
    end
  end
end
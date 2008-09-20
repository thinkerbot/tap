require 'tap/support/node'

module Tap
  module Support
    class Schema
      class << self  
        def load(task_argv)
          task_argv = YAML.load(task_argv) if task_argv.kind_of?(String)

          tasks, argv = task_argv.partition {|obj| obj.kind_of?(Array) }
          parser = new
          parser.tasks.concat(tasks)
          parser.parse(argv)
          parser
        end
        
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
      end
      
      attr_reader :nodes

      def initialize(nodes=[])
        @nodes = nodes
      end
      
      def [](index)
        nodes[index] ||= Node.new
      end
      
      # Sets the targets to the source in workflow_map, tracking the
      # workflow type.
      def set(type, options, source_index, target_indicies) # :nodoc
        targets = [*target_indicies].collect {|target_index| self[target_index] }
        self[source_index].join = Node::Join.new(type, targets, options)
      end

      def argvs
        nodes.collect do |task_definition|
          task_definition.argv
        end.delete_if {|argv| argv.empty? }
      end

      # Returns an array of [type, targets] objects; the index of
      # each entry corresponds to the task on which to build the
      # workflow.
      #
      # If a type is specified, the output is ordered differently;
      # The return is an array of [source, targets] for the 
      # specified workflow type.  In this case the order of the
      # returned array is meaningless.
      #
      def workflow(type=nil)
        declarations = []
        nodes.each_index do |source_index|
          task_definition = nodes[source_index]
          next unless task_definition

          join = task_definition.join
          next unless join && join.type == type

          target_indicies = join.targets.collect {|target| nodes.index(target) }
          declarations << [source_index, target_indicies, join.options]  
        end

        declarations
      end

      def globals
        globals = []
        nodes.each_index do |index|
          globals << index if nodes[index].source == :global
        end
        globals
      end

      # Returns an array task indicies; the index of each entry
      # corresponds to the round the tasks should be assigned to.
      #
      def rounds
        rounds = []
        nodes.each_index do |index|
          round = nodes[index].source
          (rounds[round] ||= []) << index if round.kind_of?(Integer)
        end

        rounds.each {|round| round.uniq! unless round.nil? }
        rounds
      end

      def to_s
        segments = tasks.collect do |argv| 
          argv.collect {|arg| shell_quote(arg) }.join(' ')
        end
        each_round_str {|str| segments << str }
        each_workflow_str {|str| segments << str }

        segments.join(" -- ")
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
          task, args = yield(tasks[index])
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
        rounds.each_with_index do |indicies, round_index|
          unless indicies == nil
            yield "+#{round_index}[#{indicies.join(',')}]"
          end
        end
      end

      # Yields each workflow element formatted as a string.
      def each_workflow_str # :nodoc
        workflow.each_with_index do |(type, targets), source|
          next if type == nil

          yield case type
          when :sequence   then [source, *targets].join(":")
          when :fork       then "#{source}[#{targets.join(',')}]"
          when :merge      then "#{source}{#{targets.join(',')}}"
          when :sync_merge then "#{source}(#{targets.join(',')})"
          end
        end
      end
    end
  end
end
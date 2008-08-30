module Tap
  module Support
    module Parsers
      class Base
        class << self
          # Parses the input string as YAML, if the string matches the YAML document 
          # specifier (ie it begins with "---\s*\n").  Otherwise returns the string.
          #
          #   str = {'key' => 'value'}.to_yaml       # => "--- \nkey: value\n"
          #   Tap::Script.parse_yaml(str)            # => {'key' => 'value'}
          #   Tap::Script.parse_yaml("str")          # => "str"
          def parse_yaml(str)
            str =~ /\A---\s*\n/ ? YAML.load(str) : str
          end
        end
        
        WORKFLOW_ACTIONS = %w{
          round
          sequence
          fork
          merge
          sync_merge
        } # global
        
        attr_reader :argvs
        attr_reader :rounds
        attr_reader :sequences
        attr_reader :forks
        attr_reader :merges
        attr_reader :sync_merges
        
        def build(env, app)
          # attempt lookup and instantiate the task class
          task_declarations = argvs.collect do |argv|
            pattern = argv.shift

            const = env.search(:tasks, pattern) or raise ArgumentError, "unknown task: #{pattern}"
            task_class = const.constantize or raise ArgumentError, "unknown task: #{pattern}"
            task_class.instantiate(argv, app)
          end

          # remove tasks used by the workflow
          tasks = targets.collect do |index|
            task, args = task_declarations[index]

            unless args.empty?
              raise ArgumentError, "workflow target receives args: #{task} [#{args.join(', ')}]" 
            end

            tasks[index] = nil
            task
          end

          # build the workflow
          [:sequence, :fork, :merge, :sync_merge].each do |type|
            send("#{type}s").each do |source, targets|
              source.send(type, *targets.collect {|t| tasks[t] })
            end
          end

          # build queues
          queues = rounds.collect do |round|
            round.each do |index|
              task, args = task_declarations[index]
              task.enq(*args) if task
            end

            app.queue.clear
          end
          queues.delete_if {|queue| queue.empty? }

          queues
        end
        
        protected
        
        def targets
          results = sequences.collect {|source, targets| targets } +
          forks.collect {|source, targets| targets } +
          merges.collect {|target, sources| target } +
          sync_merges.collect {|target, sources| target }
          
          results.flatten.uniq.sort
        end

      end
    end
  end
end
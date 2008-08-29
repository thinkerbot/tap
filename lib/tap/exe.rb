require 'tap/support/command_line/parser'

module Tap
  class Exe < Env
    Parser = Support::CommandLine::Parser
    
    class << self
      def instantiate
        app = Tap::App.instance
        exe = super(app, load_config(Tap::Env::GLOBAL_CONFIG_FILE), app.logger)
        
        # add all gems if no gems are specified (Note this is VERY SLOW ~ 1/3 the overhead for tap)
        if !File.exists?(Tap::Env::DEFAULT_CONFIG_FILE)
          exe.gems = gemspecs(true)
        end
      
        tap = instance_for("#{File.dirname(__FILE__)}/../..")
        tap.manifest(:tasks).search_paths = tap.root.glob(:lib, "tap/tasks/*").collect do |path|
          [tap.root[:lib], path]
        end
        exe.push(tap)
        exe
      end
      
      def instance_for(path)
        path = pathify(path)
        instances.has_key?(path) ? instances[path] : Env.instantiate(path)
      end   
    end
    
    config :before, nil
    config :after, nil
    config :aliases, {}, &c.hash_or_nil
    
    def app
      root
    end
    
    def handle_error(err)
      case
      when $DEBUG
        puts err.message
        puts
        puts err.backtrace
      else puts err.message
      end
    end
    
    def launch(argv=ARGV)
      command = argv.shift.to_s
      
      if aliases && aliases.has_key?(command)
        aliases[command].reverse_each {|arg| argv.unshift(arg)}
        command = argv.shift
      end

      case command  
      when '', '--help'
        yield
      else
        if path = search(:commands, command)
          load path # run the command, if it exists
        else
          puts "Unknown command: '#{command}'"
          puts "Type 'tap help' for usage information."
        end
      end
    end
    
    def parse(argv=ARGV)
      build(Parser.new(argv))
    end
    
    def build(parser)
      # attempt lookup and instantiate the task class
      task_declarations = parser.argvs.collect do |argv|
        pattern = argv.shift

        const = search(:tasks, pattern) or raise ArgumentError, "unknown task: #{pattern}"
        task_class = const.constantize or raise ArgumentError, "unknown task: #{pattern}"
        task_class.instantiate(argv, app)
      end
      
      # remove tasks used by the workflow
      tasks = parser.targets.collect do |index|
        task, args = task_declarations[index]
        
        unless args.empty?
          raise ArgumentError, "workflow target receives args: #{task} [#{args.join(', ')}]" 
        end
        
        tasks[index] = nil
        task
      end
      
      # build the workflow
      parser.sequences.each do |sequence|
        app.sequence(*sequence.collect {|s| tasks[s] })
      end
      
      parser.forks.each do |source, targets|
        app.fork(tasks[source], *targets.collect {|t| tasks[t] })
      end
      
      parser.merges.each do |target, sources|
        app.merge(tasks[target], *sources.collect {|s| tasks[s] })
      end
      
      parser.sync_merges.each do |target, sources|
        app.sync_merge(tasks[target], *sources.collect {|s| tasks[s] })
      end
      
      # build queues
      queues = parser.rounds.collect do |round|
        round.each do |index|
          task, args = task_declarations[index]
          task.enq(*args) if task
        end
        
        app.queue.clear
      end
      queues.delete_if {|queue| queue.empty? }
      
      queues
    end
  end
end
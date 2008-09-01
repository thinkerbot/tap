require 'tap/parser'

module Tap
  class Exe < Env

    class << self
      def instantiate(path=Dir.pwd, logger=Tap::App::DEFAULT_LOGGER, &block)
        app = Tap::App.instance = Tap::App.new({:root => path}, logger)
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
    
    def execute(argv=ARGV)
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

    def build(argv=ARGV)
      parser = Parser.new(argv)
      
      # attempt lookup and instantiate the task class
      tasks = parser.tasks.collect do |args|
        task = args.shift

        const = search(:tasks, task) or raise ArgumentError, "unknown task: #{task}"
        task_class = const.constantize or raise ArgumentError, "unknown task: #{task}"
        task_class.instantiate(args, app)
      end

      # build the workflow
      parser.workflow.each_with_index do |(type, target_indicies), source_index|
        next if type == nil
        
        tasks[source_index].send(type, *target_indicies.collect {|i| tasks[i] })
      end

      # build queues
      queues = parser.rounds.collect do |round|
        round.each do |index|
          task, args = tasks[index]
          task.enq(*args)
        end

        app.queue.clear
      end
      queues.delete_if {|queue| queue.empty? }

      queues
    end
    
    def run(queues)
      queues.each_with_index do |queue, i|
        app.queue.concat(queue)
        app.run
      end
    end
    
  end
end
require 'tap/env'
require 'tap/app'

module Tap
  class Exe < Env

    class << self
      def instantiate(path=Dir.pwd, logger=Tap::App::DEFAULT_LOGGER, &block)
        app = Tap::App.instance = Tap::App.new({:root => path}, logger)
        exe = super(app, load_config(GLOBAL_CONFIG_FILE), app.logger, &block)
        
        # add all gems if no gems are specified (Note this is VERY SLOW ~ 1/3 the overhead for tap)
        if !File.exists?(Tap::Env::DEFAULT_CONFIG_FILE)
          exe.gems = gemspecs(false)
        end
        
        # add the default tap instance
        tap = instance_for("#{File.dirname(__FILE__)}/../..")
        tap.manifest(:tasks).search_paths = tap.root.glob(:lib, "tap/tasks/*").collect do |task_path|
          [tap.root[:lib], task_path]
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
    
    # The global config file path
    GLOBAL_CONFIG_FILE = File.join(Gem.user_home, ".tap.yml")

    # Alias for root (Exe should have a Tap::App as root)
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
      Workflow.parse(argv).build(app) do |args|
        task = args.shift
        const = search(:tasks, task) 
        
        task_class = case
        when const then const.constantize 
        when block_given?
          args.unshift(task)
          yield(args)
        else nil
        end
        
        task_class or raise ArgumentError, "unknown task: #{task}"
        task_class.parse(args, app) do |help|
          puts help
          exit
        end
      end
    end
    
    def set_signals
      # info signal -- Note: some systems do 
      # not support the INFO signal 
      # (windows, fedora, at least)
      signals = Signal.list.keys
      if signals.include?("INFO")
        Signal.trap("INFO") do
          puts app.info
        end
      end

      # interuption signal
      if signals.include?("INT")
        Signal.trap("INT") do
          puts " interrupted!"
          # prompt for decision
          while true
            print "stop, terminate, exit, or resume? (s/t/e/r):"
            case gets.strip
            when /s(top)?/i 
              app.stop
              break
            when /t(erminate)?/i 
              app.terminate
              break
            when /e(xit)?/i 
              exit
            when /r(esume)?/i 
              break
            else
              puts "unexpected response..."
            end
          end
        end
      end
    end
    
    def run(queues)
      queues.each_with_index do |queue, i|
        app.queue.concat(queue)
        app.run
      end
    end
    
  end
end
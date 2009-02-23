require 'tap/env'
require 'tap/app'
require 'tap/support/schema'

module Tap
  class Exe < Env
    class << self
      def instantiate(path=Dir.pwd)
        exe = super
        
        # add all gems if no gems are specified (Note this is VERY SLOW ~ 1/3 the overhead for tap)
        exe.gems = :all if !File.exists?(Tap::Env::DEFAULT_CONFIG_FILE)
  
        # add the default tap instance
        exe.push Env.instantiate("#{File.dirname(__FILE__)}/../..")
        exe
      end
      
      def load_config(path)
        super(GLOBAL_CONFIG_FILE).merge super(path)
      end
      
      # Adapted from Gem.find_home
      def user_home
        ['HOME', 'USERPROFILE'].each do |homekey|
          return ENV[homekey] if ENV[homekey]
        end
      
        if ENV['HOMEDRIVE'] && ENV['HOMEPATH'] then
          return "#{ENV['HOMEDRIVE']}#{ENV['HOMEPATH']}"
        end

        begin
          File.expand_path("~")
        rescue
          File::ALT_SEPARATOR ? "C:/" : "/"
        end
      end
    end
    
    config :before, nil
    config :after, nil
    # Specify files to require when self is activated.
    config :requires, [], &c.array_or_nil
    
    # Specify files to load when self is activated.
    config :loads, [], &c.array_or_nil
    config :aliases, {}, &c.hash_or_nil
    
    # The global home directory
    GLOBAL_HOME = File.join(Exe.user_home, ".tap")
    
    # The global config file path
    GLOBAL_CONFIG_FILE = File.join(GLOBAL_HOME, "tap.yml")
    
    def activate
      if super      
      
        # perform requires
        requires.each do |path|
          require path
        end
      
        # perform loads
        loads.each do |path|
          load path
        end
      end
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
        if path = commands.search(command)
          load path # run the command, if it exists
        else
          puts "Unknown command: '#{command}'"
          puts "Type 'tap --help' for usage information."
        end
      end
    end

    def build(argv=ARGV, app=Tap::App.instance)
      schema = argv.kind_of?(Support::Schema) ? argv : Support::Schema.parse(argv)
      schema.build(app) do |args|
        task = args.shift
        const = tasks.search(task) 
        
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
  end
end
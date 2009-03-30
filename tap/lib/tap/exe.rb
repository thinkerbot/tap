require 'tap/env'
require 'tap/app'
require 'tap/support/schema'

module Tap
  class Exe < Env
    class << self
      def setup(argv=ARGV)
        if argv[-1] == '-d-'
          argv.pop
          $DEBUG = true 
        end
        
        instantiate
      end
      
      def instantiate(path_or_root=Dir.pwd)
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
    
    def build(schema, app=Tap::App.instance) 
      queues = schema.build do |type, argh|
        if type == :join
          instantiate_join(argh)
        else
          instantiate_task(argh, app)
        end
      end
      
      # Note this should happen in build... may need updates
      # to queue to do so
      queues.each {|queue| app.queue.concat(queue) }
      app
    end
    
    def instantiate_join(metadata)
      # Temporary!
      case metadata
      when Array
        metadata = metadata.dup
        metadata.shift # remove id that would normally look up join class
        
        join_class = Support::Join
        join_class.parse!(metadata)
      when Hash
        join_class = Support::Join
        join_class.instantiate(metadata)
      end
    end
    
    def instantiate_task(metadata, app)
      case metadata
      when Array
        metadata = metadata.dup
        tasc(metadata.shift).parse!(metadata, app)
      when Hash
        tasc(metadata[:id]).instantiate(metadata, app)
      end
    end
    
    def tasc(id)
      const = tasks.search(id) or raise ArgumentError, "unknown task: #{id}"
      const.constantize
    end
    
    def set_signals(app=Tap::App.instance)
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
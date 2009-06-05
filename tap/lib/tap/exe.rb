require 'tap/env'
require 'tap/task'
require 'tap/schema'

module Tap
  module Exe
    
    # Adapted from Gem.find_home
    # def self.user_home
    #   ['HOME', 'USERPROFILE'].each do |homekey|
    #     return ENV[homekey] if ENV[homekey]
    #   end
    # 
    #   if ENV['HOMEDRIVE'] && ENV['HOMEPATH'] then
    #     return "#{ENV['HOMEDRIVE']}#{ENV['HOMEPATH']}"
    #   end
    # 
    #   begin
    #     File.expand_path("~")
    #   rescue
    #     File::ALT_SEPARATOR ? "C:/" : "/"
    #   end
    # end

    # Setup an execution environment.
    def self.setup(options={}, argv=ARGV, env=ENV)
      if argv[-1] == "-d-"
        argv.pop
        $DEBUG = true 
      end
      
      options = {
        :dir => Dir.pwd,
        :config_file => CONFIG_FILE
      }.merge(options)
      
      # load configurations
      dir = options.delete(:dir)
      config_file = options.delete(:config_file)
      user_config_file = config_file ? File.join(dir, config_file) : nil
      
      user = Env.load_config(user_config_file)
      global = {}
      env.each_pair do |key, value|
        if key =~ /\ATAP_(.*)\z/
          global[$1.downcase] = value
        end
      end
      
      config = {
        'root' => dir,
        'gems' => :all
      }.merge(global).merge(user).merge(options)
      
      # keys must be symbolize as they are immediately 
      # used to initialize the Env configs
      config = config.inject({}) do |options, (key, value)|
        options[key.to_sym || key] = value
        options
      end
      
      # instantiate
      exe = Env.new(config, :basename => config_file).extend(Exe)
      
      exe.register('command') do |env|
        env.root.glob(:cmd, "**/*.rb")
      end
      
      # add the tap env if necessary
      unless exe.any? {|env| env.root.root == TAP_HOME }
        exe.push Env.new(TAP_HOME, exe.context) 
      end
      
      exe
    end
    
    # The config file path
    CONFIG_FILE = "tap.yml"
    
    # The home directory for Tap
    TAP_HOME = File.expand_path("#{File.dirname(__FILE__)}/../..")
    
    def launch(argv=ARGV)
      case command = argv.shift.to_s  
      when '', '--help'
        yield
      else
        if path = seek('command', command)
          load path # run the command, if it exists
        else
          puts "Unknown command: '#{command}'"
          puts "Type 'tap --help' for usage information."
        end
      end
    end
    
    def self.set_signals(app)
      # info signal -- Note: some systems do 
      # not support the INFO signal 
      # (windows, fedora, at least)
      signals = Signal.list.keys
      Signal.trap("INFO") do
        puts app.info
      end if signals.include?("INFO")

      # interuption signal
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
      end if signals.include?("INT")
    end
  end
end
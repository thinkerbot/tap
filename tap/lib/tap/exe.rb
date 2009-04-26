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
      if argv[-1] == '-d-'
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
      Tap::Env.instance = exe = Env.new(config, config_file).extend(Exe)
      
      # add the tap env if necessary
      unless exe.any? {|env| env.path == TAP_HOME }
        exe.push Env.new(TAP_HOME) 
      end
      
      exe
    end
    
    # The config file path
    CONFIG_FILE = "tap.yml"
    
    # The home directory for Tap
    TAP_HOME = File.expand_path("#{File.dirname(__FILE__)}/../..")
    
    # The global home directory
    # GLOBAL_HOME = File.join(user_home, ".tap")
    
    attr_reader :manifests
    
    def self.extended(base)
      base.instance_variable_set(:@active, false)
      base.instance_variable_set(:@manifests, {})
    end
    
    def commands
      manifests[:command] ||= manifest('commands') do |env|
        env.glob_config(:cmd_paths, "**/*.rb", :cmd)
      end
    end
    
    def generators
      manifests[:generator] ||= manifest('generator', Env::ConstantManifest) do |env|
        env.glob_config(:lib_paths, '**/*.rb', :lib) do |dir, path|
          [dir, path]
        end
      end
    end
    
    def tasks
      manifests[:task] ||= manifest('task', Env::ConstantManifest) do |env|
        env.glob_config(:lib_paths, "**/*.rb", :lib) do |dir, path|
          [dir, path]
        end
      end
      ###############################################################
      # [depreciated] manifest will be removed at 1.0
      m = manifests[:task]
      m.const_attr = /task|manifest/
      m
      ###############################################################
    end
    
    def joins
      manifests[:join] ||= manifest('join', Env::ConstantManifest) do |env|
        env.glob_config(:lib_paths, "**/*.rb", :lib) do |dir, path|
          [dir, path]
        end
      end
    end
    
    def middleware
      manifests[:middleware] ||= manifest('middleware', Env::ConstantManifest) do |env|
        env.glob_config(:lib_paths, "**/*.rb", :lib) do |dir, path|
          [dir, path]
        end
      end
    end
    
    # Activates self by doing the following, in order:
    #
    # * sets Env.instance to self (unless already set)
    # * activate nested environments
    # * unshift load_paths to $LOAD_PATH
    #
    # Once active, the current envs and load_paths are frozen and cannot be
    # modified until deactivated. Returns true if activate succeeded, or
    # false if self is already active.
    def activate
      return false if active?
      
      @active = true
      Tap::Env.instance = self
      
      # collect load paths
      @load_paths = []
      envs.each do |env|
        @load_paths << env.root[:lib]
      end
      
      # add load paths
      @load_paths.reverse_each do |path|
        $LOAD_PATH.unshift(path)
      end
      
      $LOAD_PATH.uniq!
      
      # setup manifests for build
      tasks;joins
      
      true
    end
    
    # Deactivates self by doing the following in order:
    #
    # * deactivates nested environments
    # * removes load_paths from $LOAD_PATH
    # * sets Env.instance to nil (if set to self)
    # * clears cached manifest data
    #
    # Once deactivated, envs and load_paths are unfrozen and may be modified.
    # Returns true if deactivate succeeded, or false if self is not active.
    def deactivate
      return false unless active?
      @active = false
      
      # remove load paths
      @load_paths.each do |path|
        $LOAD_PATH.delete(path)
      end
      @load_paths = nil
      
      true
    end
    
    # Return true if self has been activated.
    def active?
      @active
    end
    
    def launch(argv=ARGV)
      activate
      
      case command = argv.shift.to_s  
      when '', '--help'
        yield
      else
        if path = commands.seek(command)
          load path # run the command, if it exists
        else
          puts "Unknown command: '#{command}'"
          puts "Type 'tap --help' for usage information."
        end
      end
    end
    
    def build(schema, app=Tap::App.instance)
      schema.build do |type, metadata|
        key = case metadata
        when Array
          metadata = metadata.dup
          metadata.shift
        when Hash
          metadata[:id]
        else 
          raise "invalid metadata: #{metadata.inspect}"
        end
        
        manifest = manifests[type] or raise "invalid type: #{type.inspect}"
        klass    = manifest[key]
        
        if !klass && block_given?
          klass = yield(type, key, metadata)
        end
        
        unless klass
          raise "unknown #{type}: #{key}"
        end
        
        case metadata
        when Array then klass.parse!(metadata, app)
        when Hash  then klass.instantiate(metadata, app)
        end
      end
    end
    
    def set_signals(app)
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
    
    def run(schemas, app=Tap::App.instance, &block)
      activate
      
      schemas = [schemas] unless schemas.kind_of?(Array)
      schemas.each do |schema|
        build(schema, app, &block).each do |queue|
          app.queue.concat(queue)
        end
      end
      
      if app.queue.empty?
        raise "no task specified"
      end

      set_signals(app)
      app.run
    end
  end
end
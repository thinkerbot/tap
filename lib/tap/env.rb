require 'tap/root'
autoload(:PP, "pp")

module Tap
  class Env
    @@instance = nil
    
    class << self
      
      # Returns the active instance of Env.
      def instance
        @@instance
      end
      
      # Templates the input filepath using ERB then loads it as YAML.  
      # Returns an empty hash if the file doesn't exist, or loads to
      # nil or false (as for an empty file).  Raises an error if the
      # filepath doesn't load to a hash.
      def read_config(filepath)
        return {} if !File.exists?(filepath) || File.directory?(filepath)

        input = ERB.new(File.read(filepath)).result
        config = YAML.load(input)

        case config
        when Hash then config
        when nil, false then {}
        else
          raise "expected hash from config file: #{filepath}"
        end
      end

      # Returns the full_gem_path for the specified gem.  A gem version 
      # can be specified in the name, like 'gem >= 1.2'.  The gem will
      # be activated using +gem+ unless already active.
      def full_gem_path(gem_name)

        # figure the version of the gem, by default >= 0.0.0
        gem_name =~ /^([^<=>]*)(.*)$/
        name, version = $1.strip, $2
        version = ">= 0.0.0" if version.empty?

        # load the gem and get the spec
        gem(name, version)
        spec = Gem.loaded_specs[name]

        if spec == nil
          log(:warn, "unknown gem: #{gem_name}", Logger::WARN)
        end

        spec.full_gem_path
      end
    end
    
    include Support::Configurable
    
    # Specify gems to add to the environment.  Versions may be specified.
    config :gems, []
    
    # Specify configuration files to load into env.
    config :config_paths, [] # :nodoc:
  
    # Designate load paths.  If use_dependencies == true, then
    # load_paths will be used for automatic loading of modules
    # through the active_support Dependencies module.
    config :load_paths, ["lib"]
    
    # Specifies automatic loading of modules through Dependencies. 
    config :use_dependencies, true
    
    # Designate paths for discovering and executing commands. 
    config :command_paths, ["cmd"]

    # Designate paths for discovering generators.  
    config :generator_paths, ["lib/generators"]
    
    # An array of config keys that are resolved using root
    # when set through configure.
    PATH_CONFIGS = [:config_paths, :load_paths, :command_paths, :generator_paths]
    
    # An array of config keys that are used by configure
    # to reconfigure the root input.
    ROOT_CONFIGS = [:root, :directories, :absolute_paths]
    
    #DEFAULT_CONFIG_FILE = "tap.yml"
    
    # Gets or sets the logger for self
    attr_accessor :logger
    
    def initialize(config={}, logger=nil)
      self.config = config
      @logger = logger
      #configure(config)
    end
    
    # Logs the action and message at the input level (default INFO).
    # Logging is suppressed if no logger is set.
    def log(action, msg="", level=Logger::INFO)
     logger.add(level, msg, action.to_s) if logger
    end
    
    # Returns a list of arrays that receive load_paths on activate,
    # by default [$LOAD_PATH]. If use_dependencies == true, then
    # Dependencies.load_paths will also be included.
    def load_path_targets
      use_dependencies ? [$LOAD_PATH, Dependencies.load_paths] : [$LOAD_PATH]
    end
    
    # Activates self by unshifting load_paths for self to the load_path_targets.
    # Once active, self can be referenced from Env.instance and the current
    # configurations are frozen.  Env.instance is deactivated, if set, before
    # self is activated. Returns true if activate succeeded, or false if self 
    # is already active.
    def activate
      return false if active?
      
      unless Env.instance == nil
        Env.instance.deactivate
      end
      
      @@instance = self
      config.each_pair do |key, value|
        case value
        when Array then config[key] = value.dup.freeze
        end
      end
      
      load_path_targets.each do |target|
        load_paths.reverse_each do |path|
          target.unshift(path)
        end
        
        target.uniq!
      end
      
      true
    end
    
    # Deactivates self by deleting load_paths for self from the load_path_targets.
    # Env.instance will no longer reference self and the configurations are 
    # unfrozen (using duplication as needed, but it amounts to the same thing).
    # Returns true if deactivate succeeded, or false if self is not active.
    def deactivate
      return false unless active?
      
      @@instance = nil
      config.each_pair do |key, value|
        case value
        when Array then config[key] = value.dup
        end
      end
      
      load_path_targets.each do |target|
        load_paths.each do |path|
          target.delete(path)
        end
      end
      
      true
    end
    
    # Returns true if Env.instance == self
    def active?
      Env.instance == self
    end
    
    #--
    # Note: always yields to the block, even if non_env_configs is empty
    def configure(config, root=Tap::Root.new, &block) # :yields: non_env_configs
      
      # partiton config into its parts
      env_configs = class_configurations.default(true)
      root_configs = {}
      other_configs = {}
      
      config.each_pair do |key, value|
        key = class_configurations.normalize_key(key)
        
        partition = case 
        when class_configurations.has_config?(key) then env_configs
        when ROOT_CONFIGS.include?(key) then root_configs
        else other_configs
        end
        
        partition[key] = value
      end
      
      # assign root configs, for resolution of paths later
      unless root_configs.empty?
        root.send(:assign_paths,
          root_configs[:root] || root.root, 
          root_configs[:directories] || root.directories, 
          root_configs[:absolute_paths] || root.absolute_paths
        )
      end
      
      # resolve path_configs
      PATH_CONFIGS.each do |key|
        paths = env_configs[key]
        
        # arrayify
        paths = case paths
        when Array then paths
        when nil then []
        else [paths]
        end
        
        env_configs[key] = paths.collect {|path| root[path] }
      end
    
      # load config_paths
      env_configs.delete(:config_paths).each do |path|
        load_config(path)
      end

      # load gems
      env_configs.delete(:gems).each do |gem_name|
        load_gem(gem_name)
      end
 
      # set remaining env configs
      env_configs.each_pair do |key, value|
        set_config(key, value)
      end
      
      # handle unknown configs 
      case
      when block_given?
        yield(other_configs) 
      when !other_configs.empty?
        log(:warn, "ignoring non-env configs: #{other_configs.keys.join(',')}", Logger::DEBUG)
      end
      
      true
    end
    
    def load_config(path, root=Tap::Root.new, &block) # :yields: non_env_configs
      path = File.join(path, DEFAULT_CONFIG_FILE) if File.directory?(path)
      path = File.expand_path(path)

      # prevent infinite looping
      return false if config_paths.include?(path)
    
      # load config
      log(:load_config, path, Logger::DEBUG)
      config_paths << path
    
      config = Env.read_config(path)
      unless config.has_key?(:root) || config.has_key?('root')
        config[:root] = File.dirname(path) 
      end
    
      configure(config, root, &block)
    end
    
    # Loads the config for the specified gem.  A gem version can be 
    # specified in the name, see full_gem_path.
    def load_gem(gem_name)
      # prevent looping
      full_gem_path = Env.full_gem_path(gem_name)
      return false if gems.include?(full_gem_path)
      
      gems << full_gem_path
      load_config(full_gem_path)
    end
    
    protected
    
    def set_config(key, value)
      raise "config modification is disabled when active" if active?
      super
    end
    
    # def debug_setup
    #    $DEBUG = true
    #    logger.level = Logger::DEBUG
    #  end
    #  
    #  def rails_setup(app=Tap::App.instance)
    #    Object.const_set('RAILS_ROOT', app.root)
    #    Object.const_set('RAILS_DEFAULT_LOGGER', app.logger)
    #    Dependencies.log_activity = app.debug?
    #  end
    #  
    #  #--
    #  # TODO -- get this to only run once
    #  def rake_setup(argv=ARGV, app=Tap::App.instance)
    #    Tap::Support.autoload(:Rake, 'tap/support/rake')
    # 
    #    # setup
    #    app.extend Tap::Support::Rake
    #    rake = Rake.application.extend Tap::Support::Rake::Application
    #    rake.on_standard_exception do |error|
    #      if error.message =~ /^No Rakefile found/
    #        log(:warn, error.message, Logger::DEBUG)
    #      else raise error
    #      end
    #    end
    #    
    #    options = rake.options
    #  
    #    # merge options down from app
    #    app.options.marshal_dump.each_pair do |key, value|
    #      options.send("#{key}=", value)
    #    end
    #    options.silent = true
    #  
    #    # run as if from command line using argv
    #    current_argv = ARGV.dup
    #    begin
    #      ARGV.concat(argv)
    #      
    #      # now follow the same protocol as 
    #      # in run, handling options
    #      rake.init
    #      rake.load_rakefile
    #    ensure
    #      ARGV.clear
    #      ARGV.concat(current_argv)
    #    end
    #    
    #    rake
    #  end
    # 
    #  
    #  # Returns the path to all DEFAULT_CONFIG_FILEs for installed gems.
    #  # If latest==true, then only the config files for the latest gem
    #  # specs will be returned (ie for the most current version of a
    #  # gem).
    #  def gem_config_files(latest=true)
    #    if latest
    #      Gem.source_index.latest_specs.collect do |spec| 
    #        config_file = File.join(spec.full_gem_path, DEFAULT_CONFIG_FILE)
    #        File.exists?(config_file) ? config_file : nil
    #      end.compact
    #    else
    #      Gem.path.collect do |dir|
    #        Dir.glob( File.join(dir, "gems/*", DEFAULT_CONFIG_FILE) )
    #      end.flatten.uniq
    #    end
    #  end
    #  
    #  # Loads the config files discovered by gem_config_files(true).
    #  def discover_gems
    #    gem_config_files.collect do |config_file|
    #      load_config(config_file)
    #    end
    #  end
    #  
    #  # Searches for and returns all .rb files under each of the command_paths
    #  # as well as the default tap commands.  Commands with conflicting names
    #  # raise an error; however, user commands are allowed to override the
    #  # default tap commands and will NOT raise an error.
    #  def commands
    #    commands = {}
    #    config['command_paths'].each do |path|
    #      pattern = File.join(path, "**/*.rb")
    #      
    #      Dir.glob(pattern).each do |file|
    #        cmd = Tap::App.relative_filepath(path, file).chomp(".rb")
    #        raise "command name confict: #{cmd}" if commands.include?(cmd)
    #        commands[cmd] = file
    #      end
    #    end
    # 
    #    # allow all other scripts to override default scripts
    #    # (hence do this second)
    #    tap_command_dir = File.expand_path(File.join( File.dirname(__FILE__), "cmd"))
    #    Dir.glob( tap_command_dir + "/**/*.rb" ).each do |file|
    #      cmd = Tap::App.relative_filepath(tap_command_dir, file).chomp(".rb")
    #      commands[cmd] = file unless commands.include?(cmd)
    #    end
    # 
    #    commands
    #  end
  end
end
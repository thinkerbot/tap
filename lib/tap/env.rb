require 'tap/root'
require 'singleton'
autoload(:PP, "pp")

module Tap

  # == Under Construction
  #
  # Env manages configuration of the Tap execution environment, including the 
  # specification of gems that should be available through the tap command.
  class Env
    
    # A variety of configuration loading/handling methods for use in 
    # conjuction with Tap::Env, to aid in configuring the running
    # environment for Tap.
    module Configuration 
      module_function
      
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
      
      # Partitions a configuration hash into environment, execution,
      # and application configurations, as determined by ENV_CONFIG_KEYS
      # and EXE_CONFIG_KEYS.  All non-env, non-exe configurations are
      # considered application configurations.
      def partition_configs(hash, *sets)
        partitions = Array.new(sets.length + 1) { Hash.new }

        hash.each_pair do |key, value|
          index = 0
          sets.each do |keys|
            break if keys.include?(key)
            index += 1
          end
          
          partitions[index][key] = value
        end
        
        partitions
      end
      
      # Joins the input configuration hashes, concatenating
      # values for matching keys.  Values will be made into
      # arrays if they are not so already; duplicate values
      # are removed from the result on a key-per-key basis. 
      def join_configs(*configs)
        merge = {}
        configs.each do |hash|
          hash.each_pair do |key, values|
            values = [values] unless values.kind_of?(Array)
            (merge[key] ||= []).concat(values)
          end
        end
        merge.values.each {|values| values.uniq! }
        merge
      end
    end
    
    include Configuration
    include Singleton
    
    DEFAULT_CONFIG_FILE = "tap.yml"
    
    # Currently these are ALWAYS included.
    DEFAULT_CONFIG = {
      "load_paths" => ["lib"],
      "load_once_paths" => [],
      "config_paths" => [],
      "command_paths" => ["cmd"],
      "gems" => [],
      "generator_paths" => ["lib/generators"]
    }
    
    attr_reader :config
    attr_accessor :logger

    def initialize
      @config = nil
      @logger = nil
      reset
    end
    
    def debug_setup
      $DEBUG = true
      logger.level = Logger::DEBUG
    end
    
    def rails_setup(app=Tap::App.instance)
      Object.const_set('RAILS_ROOT', app.root)
      Object.const_set('RAILS_DEFAULT_LOGGER', app.logger)
      Dependencies.log_activity = app.debug?
    end
    
    def rake_setup(argv=ARGV, app=Tap::App.instance)
      Tap::Support.autoload(:Rake, 'tap/support/rake')

      # setup
      app.extend Tap::Support::Rake
      rake = Rake.application
      options = rake.options
    
      # merge options down from app
      app.options.marshal_dump.each_pair do |key, value|
        options.send("#{key}=", value)
      end
      options.silent = true
    
      # run as if from command line using argv
      current_argv = ARGV.dup
      begin
        ARGV.concat(argv)
        
        # now follow the same protocol as 
        # in run, handling options
        rake.init
        rake.load_rakefile
      ensure
        ARGV.clear
        ARGV.concat(current_argv)
      end
      
      rake
    end
    
    # Resets Env.  Load paths (load_paths and load_once_paths) are
    # not reset unless dependencies==true; in which case Dependencies
    # are cleared before load paths are cleared.  The load paths added
    # to $LOAD_PATH are not cleared.
    #
    # Generally not recommended.
    def reset
      unless @config == nil
        $LOAD_PATH.delete_if {|path| config['load_paths'].include?(path) }
      
        Dependencies.clear
        Dependencies.load_paths.delete_if {|path| config['load_paths'].include?(path) }
        Dependencies.load_once_paths.delete_if {|path| config['load_once_paths'].include?(path) }
      end
      
      @config = {}
      DEFAULT_CONFIG.keys.each do |key|
        @config[key] = []
      end
    end

    # Logs the action and message at the input level (default INFO).
    # Logging is suppressed if no logger is set.
    def log(action, msg="", level=Logger::INFO)
      logger.add(level, msg, action.to_s) if logger
    end
    
    # Configures the specified App using the configurations in config_file.
    # Loading of environement configurations occcurs via load_env_config;
    # all environment paths are resolved using the app, after the app has
    # been configured. 
    
    # Loads environment configurations from the specified path. If a directory 
    # is given as path, then the DEFAULT_CONFIG_FILE relative to that location 
    # will be loaded.  The loading cycle recurses as specified by the configurations.
    #
    # Configuration paths are expanded relative to the parent directory
    # of the loaded file.  Raises an error if non-env configuration are 
    # found (as determined by Tap::Env::Configurtion::ENV_CONFIG_KEYS).
    def load_config(path, root=Tap::Root.new, &block) # :yields: non_env_configs
      path = File.join(path, DEFAULT_CONFIG_FILE) if File.directory?(path)
      path = File.expand_path(path)

      # prevent infinite looping
      config_paths = config['config_paths']
      return false if config_paths.include?(path)
      
      # load config
      log(:load_config, path, Logger::DEBUG)
      config_paths << path
      
      config = read_config(path)
      config['root'] = File.dirname(path) unless config['root']
      
      configure(config, root, &block)
    end
    
    #--
    # Note: always yields to the block, even if non_env_configs is empty
    def configure(config, root=Tap::Root.new, &block) # :yields: non_env_configs
      root_configs, env_configs, other_configs = partition_configs(config, ['root', 'directories', 'absolute_paths'], DEFAULT_CONFIG.keys)
      env_configs = join_configs(DEFAULT_CONFIG, env_configs) 
      
      # assign root configs
      root.send(:assign_paths,
        root_configs['root'] || root.root, 
        root_configs['directories'] || root.directories, 
        root_configs['absolute_paths'] || root.absolute_paths)
      
      # handle unknown configs (handle before setting 
      # env configs in case the configs modify root)
      case
      when block_given?
        yield(other_configs) 
      when !other_configs.empty?
        log(:warn, "ignoring non-env configs: #{other_configs.keys.join(',')}", Logger::DEBUG)
      end
      
      # load gems and configurations 
      gem_paths = env_configs.delete('gems').collect do |gem_name| 
        full_gem_path(gem_name)
      end
      config_paths = env_configs.delete('config_paths') + gem_paths
      config_paths.each {|path| load_config(root[path]) }
      
      # assign env configs
      env_configs.each_pair do |key, value|
        case key
        when 'load_paths' 
          assign_paths(root, value, self.config[key], $LOAD_PATH, Dependencies.load_paths)
        when 'load_once_paths'
          assign_paths(root, value, self.config[key], Dependencies.load_once_paths)
        when /_paths$/ 
          assign_paths(root, value, self.config[key])
        else
          handle_unknown_env_config(root, key, value)
        end
      end

      true
    end
    
    # Loads env configurations from a gem, specifically from
    # gemspec.full_gem_path.  A gem version can be specified
    # in the name, like 'gem >= 1.2'.
    def full_gem_path(gem_name)
      # figure the version of the gem, by default >= 0.0.0
      gem_name =~ /^([^<=>]*)(.*)$/
      name, version = $1, $2
      version = ">= 0.0.0" if version.empty?

      # load the gem and get the spec
      gem(name, version)
      spec = Gem.loaded_specs[name]
      
      if spec == nil
        log(:warn, "unknown gem: #{gem_name}", Logger::WARN)
      end
      
      spec.full_gem_path
    end
    
    # Loads the config for the specified gem.  A gem version can be 
    # specified in the name, see full_gem_path.
    def load_gem(gem_name)
      load_config(full_gem_path(gem_name))
    end
    
    # Returns the path to all DEFAULT_CONFIG_FILEs for installed gems.
    # If latest==true, then only the config files for the latest gem
    # specs will be returned (ie for the most current version of a
    # gem).
    def gem_config_files(latest=true)
      if latest
        Gem.source_index.latest_specs.collect do |spec| 
          config_file = File.join(spec.full_gem_path, DEFAULT_CONFIG_FILE)
          File.exists?(config_file) ? config_file : nil
        end.compact
      else
        Gem.path.collect do |dir|
          Dir.glob( File.join(dir, "gems/*", DEFAULT_CONFIG_FILE) )
        end.flatten.uniq
      end
    end
    
    # Loads the config files discovered by gem_config_files(true).
    def discover_gems
      gem_config_files.collect do |config_file|
        load_config(config_file)
      end
    end
    
    # Searches for and returns all .rb files under each of the command_paths
    # as well as the default tap commands.  Commands with conflicting names
    # raise an error; however, user commands are allowed to override the
    # default tap commands and will NOT raise an error.
    def commands
      commands = {}
      config['command_paths'].each do |path|
        pattern = File.join(path, "**/*.rb")
        
        Dir.glob(pattern).each do |file|
          cmd = Tap::App.relative_filepath(path, file).chomp(".rb")
          raise "command name confict: #{cmd}" if commands.include?(cmd)
          commands[cmd] = file
        end
      end

      # allow all other scripts to override default scripts
      # (hence do this second)
      tap_command_dir = File.expand_path(File.join( File.dirname(__FILE__), "cmd"))
      Dir.glob( tap_command_dir + "/**/*.rb" ).each do |file|
        cmd = Tap::App.relative_filepath(tap_command_dir, file).chomp(".rb")
        commands[cmd] = file unless commands.include?(cmd)
      end

      commands
    end
    
    protected
    
    def assign_paths(root, paths, *targets)
      paths = paths.collect {|path| root[path]}
      targets.each do |array|
        paths.reverse_each do |path| 
          array.unshift(path)
        end
        array.uniq!
      end
    end
    
    def handle_unknown_env_config(key, value)
      raise "unknown env config: #{key}"
    end
  end
end
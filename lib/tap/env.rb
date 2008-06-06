require 'tap/root'
require 'tap/support/configurable'

autoload(:StringScanner, 'strscan')
#autoload(:Dependencies, 'tap/support/dependencies')
Tap::Support.autoload(:Rake, 'tap/support/rake')

module Tap

  #--
  # Note that gems and env_paths reset envs -- custom modifications to envs will be lost
  # whenever these configs are reset.
  class Env
    include Support::Configurable
    @@instance = nil
    @@instances = {}
    @@manifests = {}

    class << self  
      # Returns the active instance of Env.
      def instance
        @@instance
      end

      # A hash of (path, Env instance) pairs, generated by Env#instantiate.  Used
      # to prevent infinite loops of Env dependencies by assigning a single Env
      # to a given path.
      def instances
        @@instances
      end
      
      # Creates a new Env for the specified path and adds it to Env#instances, or 
      # returns the existing instance for the path.  Paths can point to an env config
      # file, or to a directory.  If a directory is provided, instantiate treats
      # path as the DEFAULT_CONFIG_FILE in that directory. All paths are expanded.
      #
      #   e1 = Env.instantiate("./path/to/config.yml")
      #   e2 = Env.instantiate("./path/to/dir")
      #
      #   Env.instances       
      #   # => {
      #   #  File.expand_path("./path/to/config.yml") => e1, 
      #   #  File.expand_path("./path/to/dir/#{Tap::Env::DEFAULT_CONFIG_FILE}") => e2 }
      #
      # The Env is initialized using configurations read from the env config file using
      # read_config, and a Root initialized to the config file directory. An instance 
      # will be initialized regardless of whether the config file or directory exists.
      def instantiate(path)
        if File.directory?(path) || (!File.exists?(path) && File.extname(path) == "")
          path = File.join(path, DEFAULT_CONFIG_FILE) 
        end
        path = File.expand_path(path)
        
        # return the existing instance if possible
        return instances[path] if instances.has_key?(path)
        
        # note the assignment of env to instances MUST occur before
        # reconfigure to prevent infinite looping
        (instances[path] = Env.new({}, Root.new(File.dirname(path)))).reconfigure(read_config(path))
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
      def gemspec(gem_name)
        return gem_name if gem_name.kind_of?(Gem::Specification)
        
        # figure the version of the gem, by default >= 0.0.0
        gem_name.to_s =~ /^([^<=>]*)(.*)$/
        name, version = $1.strip, $2
        version = ">= 0.0.0" if version.empty?
        
        return nil if name.empty?
        
        # load the gem and get the spec
        gem(name, version)
        Gem.loaded_specs[name]
      end
      
      #--
      # Returns the path to all DEFAULT_CONFIG_FILEs for installed gems.
      # If latest==true, then only the config files for the latest gem
      # specs will be returned (ie for the most current version of a
      # gem).
      # def env_gemspecs(latest=true)
      #   if latest
      #     Gem.source_index.latest_specs.collect do |spec| 
      #       config_file = File.join(spec.full_gem_path, DEFAULT_CONFIG_FILE)
      #       File.exists?(config_file) ? spec : nil
      #     end.compact
      #   else
      #     Gem.path.collect do |dir|
      #       Dir.glob( File.join(dir, "gems/*", DEFAULT_CONFIG_FILE) )
      #     end.flatten.uniq
      #   end
      # end
      
      protected
      
      # Defines a config that raises an error if set when the 
      # instance is active.  static_config MUST take a block
      # and raises an error if a block is not given.
      def static_config(key, value=nil, &block)
        raise ArgumentError.new("active config requires block") unless block_given?
        
        instance_variable = "@#{key}".to_sym
        config_attr(key, value) do |input|
          check_configurable
          instance_variable_set(instance_variable, block.call(input))
        end
      end
      
      # Defines a config that collects the input into a unique,
      # compact array where each member has been resolved using
      # root[].  In short, ['lib', nil, 'lib', 'alt] becomes
      # [root['lib'], root['alt']].
      #
      # Single and nil arguments are allowed; they are arrayified
      # and handled as above.  Path configs raise an error if
      # modified when the instance is active.
      def path_config(key, value=[]) 
        instance_variable = "@#{key}".to_sym
        config_attr(key, value) do |input|
          check_configurable
          instance_variable_set(instance_variable, [*input].compact.collect {|path| root[path]}.uniq)
        end
      end
      
      #--
      # Alternate implementation would create the manifest for each individual
      # env, then merge the manifests.  On the plus side, each env would then
      # carry it's own slice of the manifest without having to recalculate.
      # On the down side, the merging would have to occur in some separate
      # method that cannot be defined here.
      def manifest(manifest_key, paths_key, default={}, reverse=true, &block)
        manifest_key = manifest_key.to_sym
        paths_key = paths_key.to_sym
        discover_method = "discover_#{manifest_key}".to_sym
        
        define_method(discover_method, &block)
        protected discover_method
        
        define_method(manifest_key) do
          manifest = manifests[manifest_key]
          return manifest unless manifest == nil
          
          manifest = default.dup
          send(reverse ? :reverse_each : :each) do |env|
            env.send(paths_key).each do |path|
              env.send(discover_method, manifest, path)
            end
          end
          manifests[manifest_key] = manifest
        end
      end
    end
    
    # The default config file path
    DEFAULT_CONFIG_FILE = "tap.yml"
    
    # The Root directory structure for self.
    attr_reader :root
    
    # Gets or sets the logger for self
    attr_accessor :logger
    
    # An array of nested Envs, by default comprised of the
    # env_path + gem environments (in that order).  These
    # nested Envs are activated/deactivated with self.
    #
    # Manual modification of envs is allowed, with the caveat 
    # that any reconfiguration of env_paths or gems will result
    # in a reset of envs to the default env_path + gem 
    # environments.
    attr_reader :envs
    
    # A hash of the calculated manifests.
    attr_reader :manifests
    
    # Specify gems to load as nested Envs.  Gems may be specified 
    # by name and/or version, like 'gemname >= 1.2'; by default the 
    # latest version of the gem is selected.
    #
    # Gems are immediately loaded (via gem) through this method.
    #--
    # Note that the gems are resolved to gemspecs using Env.gemspec,
    # so self.gems returns an array of gemspecs.
    config_attr :gems, [] do |input|
      check_configurable
      @gems = [*input].compact.collect do |gem_name| 
        spec = Env.gemspec(gem_name)
        
        case spec
        when nil then log(:warn, "unknown gem: #{gem_name}", Logger::WARN)
        else Env.instantiate(spec.full_gem_path)
        end
        
        spec
      end.uniq
      reset_envs
    end

    # Specify configuration files to load as nested Envs.
    config_attr :env_paths, [] do |input|
      check_configurable
      @env_paths = [*input].compact.collect do |path| 
        Env.instantiate(root[path]).env_path
      end.uniq
      reset_envs
    end
 
    # Designate load paths.  If use_dependencies == true, then
    # load_paths will be used for automatic loading of modules
    # through the active_support Dependencies module.
    path_config :load_paths, ["lib"]
    
    # Designate paths for discovering and executing commands. 
    path_config :command_paths, ["cmd"]
    
    # Designate paths for discovering generators.  
    path_config :generator_paths, ["lib/generators"]
    
    # Specifies automatic loading of dependencies through
    # the active_support Dependencies module.  Naturally,
    # active_support must be installed for this to work.
    static_config :use_dependencies, false, &c.boolean
    
    config :debug, false, &c.boolean
    
    TASK_MANIFEST_REGEXP = /#\s*:discover:/
    
    manifest(:tasks, :load_paths) do |tasks, load_path|
      root.glob(load_path, "**/*.rb").each do |fullpath|
        
        scanner = StringScanner.new(File.read(fullpath))
        next unless scanner.skip_until(TASK_MANIFEST_REGEXP)
          
        path = root.relative_filepath(load_path, fullpath)
        name = path.chomp('.rb')
          
        class_name = scanner.scan_until(/$/).strip
        class_name = name.camelize if class_name.empty?
          
        tasks[name] = {:class_name => class_name, :path => path, :load_path => load_path, :env => self}
      end
    end
    
    # A hash of the default tap commands.
    DEFAULT_COMMANDS = {}
    Dir.glob(File.dirname(__FILE__) + "/cmd").each do |path|
      cmd = File.basename(path).chomp(".rb")
      DEFAULT_COMMANDS[cmd] = File.expand_path(path)
    end
    
    # --
    # Searches for and returns all .rb files under each of the command_paths
    # as well as the default tap commands.  Commands with conflicting names
    # raise an error; however, user commands are allowed to override the
    # default tap commands and will NOT raise an error.
    manifest(:commands, :command_paths, DEFAULT_COMMANDS) do |commands, command_path|
      root.glob(command_path, "**/*.rb").each do |path|
        cmd = root.relative_filepath(command_path, path).chomp(".rb")
        if commands.include?(cmd)
          log :warn, "command name confict: #{cmd} (overriding '#{commands[cmd]}' with '#{path}')", Logger::DEBUG
        end
        
        commands[cmd] = path
      end
    end

    # A hash of the default tap generators.
    DEFAULT_GENERATORS = {}
    Dir.glob(File.dirname(__FILE__) + "/generator/generators/*/*_generator.rb").each do |path|
      generator = File.basename(path).chomp("_generator.rb")
      DEFAULT_GENERATORS[generator] = File.expand_path(path)
    end

    manifest(:generators, :generator_paths, DEFAULT_GENERATORS) do |generators, generator_path|
      root.glob(generator_path, "**/*_generator.rb").each do |path|
        generator = root.relative_filepath(generator_path, path).chomp("_generator.rb")
        if generators.include?(cmd)
          log :warn, "generator name confict: #{generator} (overriding '#{generators[cmd]}' with '#{path}')", Logger::DEBUG
        end
        
        generators[generator] = path
      end
    end
    
    def initialize(config={}, root=Tap::Root.new, logger=nil)
      @root = root 
      @logger = logger
      @envs = []
      @active = false
      @manifests = {}
      
      # initialize these for reset_env
      @gems = []
      @env_paths = []
      
      initialize_config(config)
    end
    
    # Should be added to ensure nested configs don't set this...
    # def use_dependencies
    #   use_dependencies && self == Env.instance
    # end
    
    def constantize(str)
      str.camelize.try_constantize do |const_name|
        log(:warn, "NameError: #{const_name}", Logger::DEBUG)
        
        path_suffix = const_name.underscore.chomp('.rb') + '.rb'

        load_paths.inject(nil) do |obj, base|
          break(obj) if obj != nil

          path = File.join(base, path_suffix) # should already be expanded
          next unless File.exists?(path) 

          log(:crequire, path, Logger::DEBUG)
          require path
          constantize(const_name)
        end
      end
    end
    
    # Returns a list of arrays that receive load_paths on activate,
    # by default [$LOAD_PATH]. If use_dependencies == true, then
    # Dependencies.load_paths will also be included.
    def load_path_targets
      use_dependencies ? [$LOAD_PATH, Dependencies.load_paths] : [$LOAD_PATH]
    end
    
    # Unloads constants loaded by Dependencies, so that they will be reloaded
    # (with any changes made) next time they are called.  Does nothing unless
    # use_dependencies == true.  Returns the unloaded constants, or nil if 
    # use_dependencies is false.
    def reload
      return nil unless use_dependencies
      
      unloaded = []
    
      # echos the behavior of Dependencies.clear, 
      # but collects unloaded constants
      Dependencies.loaded.clear
      Dependencies.autoloaded_constants.each do |const| 
        Dependencies.remove_constant const
        unloaded << const
      end
      Dependencies.autoloaded_constants.clear
      Dependencies.explicitly_unloadable_constants.each do |const| 
        Dependencies.remove_constant const
        unloaded << const
      end
    
      unloaded
    end
    
    # Processes and resets the input configurations for both root
    # and self. Reconfiguration consists of the following steps:
    #
    # * partition overrides into env, root, and other configs
    # * reconfigure root with the root configs
    # * reconfigure self with the env configs
    # * yield other configs to the block (if given)
    #
    # Reconfigure will always yields to the block, even if there
    # are no non-root, non-env configurations.  Unspecified 
    # configurations are NOT reconfigured.  (Note this means 
    # that existing path configurations like load_paths will 
    # not automatically be reset using reconfigured root.)
    def reconfigure(overrides={})
      check_configurable
      
      # partiton config into its parts
      env_configs = {}
      root_configs = {}
      other_configs = {}
      
      env_configurations = self.class.configurations
      root_configurations = root.class.configurations
      overrides.each_pair do |key, value|
        key = key.to_sym
    
        partition = case 
        when env_configurations.key?(key) then env_configs
        when root_configurations.key?(key) then root_configs
        else other_configs
        end
    
        partition[key] = value
      end
    
      # reconfigure root so it can resolve path_configs
      root.reconfigure(root_configs)
      
      # reconfigure self
      super(env_configs)
      
      # handle other configs 
      case
      when block_given?
        yield(other_configs) 
      when !other_configs.empty?
        log(:warn, "ignoring non-env configs: #{other_configs.keys.join(',')}", Logger::DEBUG)
      end
      
      self
    end
    
    # Returns the path for self in Env.instances.
    def env_path
      Env.instances.each_pair {|path, env| return path if env == self }
      nil
    end
    
    # Logs the action and message at the input level (default INFO).
    # Logging is suppressed if no logger is set.
    def log(action, msg="", level=Logger::INFO)
      logger.add(level, msg, action.to_s) if logger
    end
    
    # Activates self by unshifting load_paths for self to the load_path_targets.
    # Once active, self can be referenced from Env.instance and the current
    # configurations are frozen.  Env.instance is deactivated, if set, before
    # self is activated. Returns true if activate succeeded, or false if self 
    # is already active.
    def activate
      return false if active?
      
      @active = true
      @@instance = self unless @@instance
      
      # freeze array configs like load_paths
      config.each_pair do |key, value|
        case value
        when Array then value.freeze
        end
      end
      
      # activate nested envs
      envs.reverse_each do |env|
        env.activate
      end

      # add load paths to load_path_targets
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
      
      # remove load paths from load_path_targets
      load_path_targets.each do |target|
        load_paths.each do |path|
          target.delete(path)
        end
      end
      
      # unfreeze array configs by duplicating
      self.config.class_config.each_pair do |key, value|
        value = send(key)
        case value
        when Array then instance_variable_set("@#{key}", value.dup)
        end
      end
      
      @active = false
      @@instance = nil if @@instance == self
      
      # dectivate nested envs
      envs.reverse_each do |env|
        env.deactivate
      end
      
      true
    end
    
    # Return true if self has been activated.
    def active?
      @active
    end
    
    # Passes each nested env to the block in order, starting with self.
    def each
      yield(self)
      envs.each do |env|
        env.each do |e|
          yield(e)
        end
      end
    end
    
    # Passes each nested env to the block in reverse order, ending with self.
    def reverse_each
      envs.reverse_each do |env|
        env.reverse_each do |e|
          yield(e)
        end
      end
      yield(self)
    end

    #
    # Under construction
    #
    
    # # Loads the config for the specified gem.  A gem version can be 
    # # specified in the name, see full_gem_path.
    # def load_gem(gem_name)
    #   # prevent looping
    #   full_gem_path = full_gem_path(gem_name)
    #   return false if gems.include?(full_gem_path)
    # 
    #   gems << full_gem_path
    #   load_config(full_gem_path)
    # end
    # 
    # # Loads the config files discovered by gem_config_files(true).
    # def discover_gems
    #   gem_config_files.collect do |config_file|
    #     load_config(config_file)
    #   end
    # end
    
    def handle_error(err)
      case
      when $DEBUG
        puts err.message
        puts
        puts err.backtrace
      when debug then raise err
      else puts err.message
      end
    end
    
    def debug?
      $DEBUG || debug
    end
    
    def debug_setup
      $DEBUG = true
      logger.level = Logger::DEBUG if logger
    end
    
    def rails_setup
      Object.const_set('RAILS_ROOT', root.root)
      Object.const_set('RAILS_DEFAULT_LOGGER', logger)
      Dependencies.log_activity = debug?
    end
    
    #--
    # TODO -- get this to only run once
    def rake_setup(argv=ARGV)
      rake = Tap::Support::Rake.application
      rake.on_standard_exception do |error|
        if error.message =~ /^No Rakefile found/
          log(:warn, error.message, Logger::DEBUG)
        else raise error
        end
      end
    
      options = rake.options
      # merge options down from app
      # app.options.marshal_dump.each_pair do |key, value|
      #   options.send("#{key}=", value)
      # end
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
    
    protected
    
    def check_configurable
      raise "path configurations are disabled when active" if active?
    end
    
    def reset_envs
      @envs = env_paths.collect do |path| 
        Env.instances[path]
      end + gems.collect do |spec|
        Env.instances[spec.full_gem_path]
      end.uniq
    end
  end
end
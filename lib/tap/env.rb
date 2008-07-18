require 'tap/root'

# causes an error with generators... something in the way Dependencies is set...
# autoload(:Dependencies, 'tap/support/dependencies')
Tap::Support.autoload(:Rake, 'tap/support/rake')

module Tap

  #--
  # Note that gems and env_paths reset envs -- custom modifications to envs will be lost
  # whenever these configs are reset.
  class Env
    include Support::Configurable
    include Enumerable
    
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
      def instantiate(path_or_root, default_config={}, logger=nil)
        path = path_or_root.kind_of?(Root) ? path_or_root.root : path_or_root
        path = pathify(path)
        
        begin
          root = path_or_root.kind_of?(Root) ? path_or_root : Root.new(File.dirname(path))
          config = default_config.merge(read_config(path))
          
          # note the assignment of env to instances MUST occur before
          # reconfigure to prevent infinite looping
          (instances[path] = Env.new({}, root, logger)).reconfigure(config) do |unhandled_configs|
            yield(unhandled_configs) if block_given?
          end
        rescue(Exception)
          raise Env::ConfigError.new($!, path)
        end
      end
      
      def pathify(path)
        if File.directory?(path) || (!File.exists?(path) && File.extname(path) == "")
          path = File.join(path, DEFAULT_CONFIG_FILE) 
        end
        File.expand_path(path)
      end
      
      def instance_for(path)
        path = pathify(path)
        instances.has_key?(path) ? instances[path] : instantiate(path)
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

      # Returns the gemspec for the specified gem.  A gem version 
      # can be specified in the name, like 'gem >= 1.2'.  The gem 
      # will be activated using +gem+ if necessary.
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
      
      # Returns the gem name for all installed gems with a DEFAULT_CONFIG_FILE.
      # If latest==true, then only the names for the most current gem specs
      # will be returned.
      def known_gems(latest=true)
        index = latest ?
          Gem.source_index.latest_specs :
          Gem.source_index.gems.collect {|(name, spec)| spec }
        
        index.collect do |spec|
          config_file = File.join(spec.full_gem_path, DEFAULT_CONFIG_FILE)
          File.exists?(config_file) ? spec : nil
        end.compact.sort
      end
      
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
      def manifest(name, paths_key, extname=".rb", &block)
        return manifest(name, paths_key, extname) do |manifest_path, path| 
          path.chomp(extname) 
        end unless block_given?
        
        manifest_keys = "keys_for_#{name}_manifest".to_sym
        
        define_method(manifest_keys, &block)
        protected manifest_keys
        
        # tasks => {key => path}
        # iterate_tasks(pattern=nil) :yields: key, path
        # tasks_keys
        
        module_eval %Q{
          def iterate_#{name}(pattern='**/*#{extname}')
            self.#{paths_key}.each do |manifest_path|
              root.glob(manifest_path, pattern).each do |path|
                keys = self.#{manifest_keys}(manifest_path, path)
                case keys
                when Array then keys.each {|key| yield(key, path) }
                when Hash then keys.each_pair {|key, value| yield(key, value) }
                when nil then next
                else yield(keys, path)
                end
              end
            end
          end
        }

      end
    end
    
    # The global config file path
    GLOBAL_CONFIG_FILE = File.join(Gem.user_home, ".tap.yml")
    
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
        else Env.instance_for(spec.full_gem_path)
        end
        
        spec
      end.uniq
      reset_envs
    end

    # Specify configuration files to load as nested Envs.
    config_attr :env_paths, [] do |input|
      check_configurable
      @env_paths = [*input].compact.collect do |path| 
        Env.instance_for(root[path]).env_path
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
    
    #-- TODO - move to tap as unhandled configs
    
    # Specifies automatic loading of dependencies through
    # the active_support Dependencies module.  Naturally,
    # active_support must be installed for this to work.
    static_config :use_dependencies, false, &c.boolean
    config :debug, false, &c.boolean  
    config :short_run_options, ['--dump', '--rake'], &c.array
    
    #--
    
    manifest(:tasks, :load_paths) do |load_path, path|
      document = Support::Lazydoc[path]
        
      Support::Lazydoc.scan(File.read(path), 'manifest') do |const_name, key, comment|
        document.attributes(const_name)[key] = comment
      end
        
      document.const_names.collect do |const_name|
        const_name == "" ? root.relative_filepath(load_path, path).chomp('.rb') : const_name.underscore
      end
    end
    
    # --
    # Searches for and returns all .rb files under each of the command_paths
    # as well as the default tap commands.  Commands with conflicting names
    # raise an error; however, user commands are allowed to override the
    # default tap commands and will NOT raise an error.
    manifest(:commands, :command_paths) 
    
    #manifest(:generators, :generator_paths, '_generator.rb') 
    
    def initialize(config={}, root=Tap::Root.new, logger=nil)
      @root = root 
      @logger = logger
      @envs = []
      @active = false
      @manifests = {}
      @manifested = []
      
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

        $:.each do |load_path|
          path = File.join(load_path, path_suffix) # should already be expanded
          next unless File.exists?(path) 

          log(:crequire, path, Logger::DEBUG)
          require path
          break
        end
        
        const_name.try_constantize do |const_name|
          yield(const_name) if block_given?
        end
      end
    end
    
    # Returns a list of arrays that receive load_paths on activate,
    # by default [$LOAD_PATH]. If use_dependencies == true, then
    # Dependencies.load_paths will also be included.
    def load_path_targets
      use_dependencies ? [$LOAD_PATH, ::Dependencies.load_paths] : [$LOAD_PATH]
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
    
    # Deactivates self by clearing manifests and deleting load_paths for self 
    # from the load_path_targets. Env.instance will no longer reference self 
    # and the configurations are unfrozen (using duplication).
    #
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
      @manifests.clear
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
    
    def unshift(env)
      self.envs = envs.unshift(env)
    end
    
    def push(env)
      self.envs = envs.push(env)
    end
    
    # Passes each nested env to the block in order, starting with self.
    def each
      yield(self)
      visited = [self]
      
      envs.each do |env|
        next if visited.include?(env)
        
        env.each do |e|
          next if visited.include?(e)
          yield(e)
          visited << e
        end
      end
    end
    
    # Passes each nested env to the block in reverse order, ending with self.
    def reverse_each
      visited = []
      envs.reverse_each do |env|
        next if visited.include?(env)
        
        env.reverse_each do |e|
          next if visited.include?(e)
          yield(e)
          visited << e
        end
      end
      yield(self)
    end
    
    def count
      count = 0
      each {|e| count += 1 }
      count
    end
    
    def manifested?(name)
      @manifested.include?(name)
    end
    
    def manifest(name)
      manifest = manifests[name] ||= {}
      return manifest if manifested?(name)
      
      send("iterate_#{name}") {|key, path| add_manifest(manifest, key, path) }
      @manifested << name
      manifest
    end
    
    def reduce_map(name)
      Tap::Root.reduce_map(manifest(name), false)
    end
    
    def map(name)
      maps = []
      reduce_map(:envs).each_pair do |key, env|
       map = env.reduce_map(name).to_a.sort_by {|(k,v)| k }
       maps << [key, env, map] unless map.empty?
      end
      maps
    end
    
    def find(name, pattern)
      manifest = manifests[name] ||= {}
      send("iterate_#{name}", "**/*#{pattern}*") do |key, path|
        add_manifest(manifest, key, path)
        return [key, path] if manifest_match?(key, pattern)
      end unless manifested?(name)
      
      # does this need to be run when the first search fails?
      # may depend on the pattern being input... does it filter
      # out the matching pattern...
      self.manifest(name).each_pair do |key, path| 
        return [key, path] if manifest_match?(key, pattern)
      end
      
      nil
    end
    
    def search(name, pattern)
      return find(name, pattern) if name == :envs
      
      envs = case pattern
      when /^(.*):([^:]+)$/
        env_pattern = $1
        pattern = $2
        if match = find(:envs, env_pattern) 
          match[1] 
        else
          raise(ArgumentError, "could not find env: #{env_pattern}")
        end
      else self
      end
      
      envs.each do |env|
        if result = env.find(name, pattern)
          return result
        end
      end
      
      nil
    end

    def inspect(brief=false)
      brief ? "#<#{self.class}:#{object_id} root='#{root.root}'>" : super()
    end

    #
    # Under construction
    #
    
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
    
    def iterate_envs(pattern=nil)
      each do |env|
        yield(env.root.root, env)
      end
    end    
    
    def add_manifest(manifest, key, path)
      raise 'ManifestConflict' if manifest.has_key?(key) && manifest[key] != path
      manifest[key] = path
    end
    
    def manifest_match?(key, pattern)
      # key ends with pattern AND basenames of each are equal... 
      # the last check ensures that a full path segment has 
      # been specified
      key[-pattern.length, pattern.length] == pattern #&& File.basename(key) == File.basename(pattern)
    end
    
    def check_configurable
      raise "path configurations are disabled when active" if active?
    end
    
    def check_consistency
      envs == envs.uniq.delete_if {|e| e == self }
    end
    
    def envs=(envs)
      @envs = envs.uniq.delete_if {|e| e == self }
    end
    
    def reset_envs
      self.envs = env_paths.collect do |path| 
        Env.instance_for(path)
      end + gems.collect do |spec|
        Env.instance_for(spec.full_gem_path)
      end
    end
    
    class InconsistencyError < StandardError
    end
    
    class ConfigError < StandardError
      attr_reader :original_error, :env_path
      
      def initialize(original_error, env_path)
        @original_error = original_error
        @env_path = env_path
        super()
      end
      
      def message
        "Configuration error: #{original_error.message}\n" +
        ($DEBUG ? "#{original_error.backtrace}\n" : "") + 
        "Check '#{env_path}' configurations"
      end
    end
  end
end
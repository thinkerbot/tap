require 'tap/root'
require 'tap/env/constant_manifest'
require 'tap/support/intern'
require 'tap/support/templater'
autoload(:YAML, 'yaml')

module Tap
  # Env abstracts an execution environment that spans many directories.
  class Env
    autoload(:Gems, 'tap/env/gems')
  
    class << self
      attr_writer :instance
      
      def instance(auto_initialize=true)
        @instance ||= (auto_initialize ? new : nil)
      end
      
      def from_gemspec(spec, basename=nil, cache={})
        path = spec.full_gem_path
        
        dependencies = []
        spec.dependencies.each do |dependency|
          unless dependency.type == :runtime
            next
          end
          
          unless gemspec = Gems.gemspec(dependency)
            # this error may result when a dependency has
            # been uninstalled for a particular gem
            warn "missing gem dependency: #{dependency.to_s} (#{spec.full_name})"
            next
          end
          
          if basename && !File.exists?(File.join(gemspec.full_gem_path, basename))
            next
          end
          
          dependencies << gemspec
        end
        
        config = {
          :root => path,
          :gems => dependencies,
          :load_paths => spec.require_paths,
          :set_load_paths => false
        }
        
        if basename
          config.merge!(Env.load_config(File.join(path, basename)))
        end
        
        new(config, basename, cache)
      end
      
      # Loads configurations from path as YAML.  Returns an empty hash if the path
      # loads to nil or false (as happens for empty files), or doesn't exist.
      def load_config(path)
        return {} unless path
        
        begin
          Root::Utils.trivial?(path) ? {} : (YAML.load_file(path) || {})
        rescue(Exception)
          raise ConfigError.new($!, path)
        end
      end
    end
    self.instance = nil
    
    include Enumerable
    include Configurable
    include Minimap
    
    # Matches a compound registry search key.  After the match, if the key is
    # compound then:
    #
    #  $1:: env_key
    #  $2:: key
    #
    # If the key is not compound, $2 is nil and $1 is the key.
    COMPOUND_KEY = /^((?:[A-z]:(?:\/|\\))?.*?)(?::(.*))?$/
  
    # An array of nested Envs, by default comprised of the env_path
    # + gem environments (in that order).
    attr_reader :envs
    
    # The basename for dynamically loading configurations.  See new.
    attr_reader :basename
    
    # A cache of data internally used for optimization and to prevent infinite
    # loops for nested envs.  Not recommended for casual use.
    attr_reader :cache
    
    attr_reader :manifests
    
    # The Root directory structure for self.
    nest(:root, Root, :set_default => false)
  
    # Specify gems to add as nested Envs.  Gems may be specified 
    # by name and/or version, like 'gemname >= 1.2'; by default the 
    # latest version of the gem is selected.  Gems are not activated
    # by Env.
    config_attr :gems, [] do |input|
      input = yaml_load(input) if input.kind_of?(String)
      
      @gems = case input
      when false, nil, :NONE, :none
        []
      when :LATEST, :ALL
        # latest and all, no filter
        Gems.select_gems(input == :LATEST)
      when :latest, :all
        # latest and all, filtering by basename
        Gems.select_gems(input == :latest) do |spec|
          basename == nil || File.exists?(File.join(spec.full_gem_path, basename))
        end
      else
        # resolve gem names manually
        [*input].collect do |name|
          Gems.gemspec(name)
        end.compact
      end
    
      reset_envs
    end

    # Specify directories to load as nested Envs.
    config_attr :env_paths, [] do |input|
      @env_paths = resolve_paths(input)
      reset_envs
    end
    
    # Designates paths added to $LOAD_PATH on activation (see set_load_paths).
    # These paths are also the default directories searched for resources.
    config_attr :load_paths, [:lib] do |input|
      raise "load_paths cannot be modified once active" if active?
      @load_paths = resolve_paths(input)
    end
    
    # If set to true load_paths are added to $LOAD_PATH on activation.
    config_attr :set_load_paths, true do |input|
      raise "set_load_paths cannot be modified once active" if active?
      @set_load_paths = Configurable::Validation.boolean[input]
    end
    
    # A hash of resources registered with env, used to build manifests.
    config :registry, {}, &c.hash
    
    # Initializes a new Env linked to the specified directory.  A config file
    # basename may be specified to load configurations from 'dir/basename' as
    # YAML.  If a basename is specified, the same basename will be used to 
    # load configurations for nested envs.
    #
    # Configurations may be manually provided in the place of dir.  In that
    # case, the same rules apply for loading configurations for nested envs,
    # but no configurations will be loaded for the current instance.
    #
    # The cache is used internally to prevent infinite loops of nested envs,
    # and to optimize the generation of manifests.
    def initialize(config_or_dir=Dir.pwd, basename=nil, cache={})
      @active = false
      @manifests = {}
      
      # setup root
      config = nil
      @root = case config_or_dir
      when Root   then config_or_dir
      when String then Root.new(config_or_dir)
      else
        config = config_or_dir
        root = config.delete(:root) || Dir.pwd
        root.kind_of?(Root) ? root : Root.new(root)
      end
      
      # load configurations if specified
      @basename = basename
      if basename && !config
        config = Env.load_config(File.join(@root.root, basename))
      end
      
      # set instances
      @cache = cache
      if cached_env(@root.root)
        raise "cache already has an env for: #{@root.root}"
      end
      cache[:env] << self
      
      # set these for reset_env
      @gems = nil
      @env_paths = nil
      initialize_config(config || {})
    end
    
    # The minikey for self (root.root).
    def minikey
      root.root
    end
    
    def reset
      each do |env| 
        env.cache.delete_if {|k, v| k != :env }
        env.registry.clear
        env.manifests.clear
      end
    end
    
    # Sets envs removing duplicates and instances of self.  Setting envs
    # overrides any environments specified by env_path and gem.
    def envs=(envs)
      raise "envs cannot be modified once active" if active?
      @envs = envs.uniq.delete_if {|env| env == self }
    end
  
    # Unshifts env onto envs. Self cannot be unshifted onto self.
    def unshift(env)
      unless env == self || envs[0] == env
        self.envs = envs.dup.unshift(env)
      end
      self
    end
  
    # Pushes env onto envs, removing duplicates.  
    # Self cannot be pushed onto self.
    def push(env)
      unless env == self || envs[-1] == env
        envs = self.envs.reject {|e| e == env }
        self.envs = envs.push(env)
      end
      self
    end
  
    # Passes each nested env to the block in order, starting with self.
    def each
      visit_envs.each {|e| yield(e) }
    end
  
    # Passes each nested env to the block in reverse order, ending with self.
    def reverse_each
      visit_envs.reverse_each {|e| yield(e) }
    end
    
    # Recursively injects the memo to each env of self.  Each env in envs
    # receives the same memo from the parent.  This is different from the
    # inject provided via Enumerable, where each subsequent env receives
    # the memo from the previous, not the parent, env.
    #
    #   a,b,c,d,e = ('a'..'e').collect {|name| Env.new(:name => name) }
    # 
    #   a.push(b).push(c)
    #   b.push(d).push(e)
    # 
    #   lines = []
    #   a.recursive_inject(0) do |nesting_depth, env|
    #     lines << "\n#{'..' * nesting_depth}#{env.config[:name]} (#{nesting_depth})"
    #     nesting_depth + 1
    #   end
    #
    #   lines.join
    #   # => %Q{
    #   # a (0)
    #   # ..b (1)
    #   # ....d (2)
    #   # ....e (2)
    #   # ..c (1)}
    #
    def recursive_inject(memo, &block) # :yields: memo, env
      inject_envs(memo, &block)
    end
    
    # Activates self by doing the following, in order:
    #
    # * sets Env.instance to self (unless already set)
    # * activate nested environments
    # * unshift load_paths to $LOAD_PATH (if set_load_paths is true)
    #
    # Once active, the current envs and load_paths are frozen and cannot be
    # modified until deactivated. Returns true if activate succeeded, or
    # false if self is already active.
    def activate
      return false if active?
      
      @active = true
      unless self.class.instance(false)
        self.class.instance = self
      end
      
      # freeze envs and load paths
      @envs.freeze
      @load_paths.freeze
      
      # activate nested envs
      envs.reverse_each do |env|
        env.activate
      end
      
      # add load paths
      if set_load_paths
        load_paths.reverse_each do |path|
          $LOAD_PATH.unshift(path)
        end
      
        $LOAD_PATH.uniq!
      end
      
      true
    end
    
    # Deactivates self by doing the following in order:
    #
    # * deactivates nested environments
    # * removes load_paths from $LOAD_PATH (if set_load_paths is true)
    # * sets Env.instance to nil (if set to self)
    # * clears cached manifest data
    #
    # Once deactivated, envs and load_paths are unfrozen and may be modified.
    # Returns true if deactivate succeeded, or false if self is not active.
    def deactivate
      return false unless active?
      @active = false
      
      # dectivate nested envs
      envs.reverse_each do |env|
        env.deactivate
      end
      
      # remove load paths
      load_paths.each do |path|
        $LOAD_PATH.delete(path)
      end if set_load_paths
      
      # unfreeze envs and load paths
      @envs = @envs.dup
      @load_paths = @load_paths.dup
      
      # clear cached data
      klass = self.class
      if klass.instance(false) == self
        klass.instance = nil
      end
      
      true
    end
    
    # Return true if self has been activated.
    def active?
      @active
    end
    
    def hlob(dir, pattern="**/*")
      results = {}
      each do |env|
        root = env.root
        root.glob(dir, pattern).each do |path|
          relative_path = root.relative_path(dir, path)
          results[relative_path] ||= path
        end
      end
      results
    end
    
    def glob(dir, pattern="**/*")
      hlob(dir, pattern).values.sort!
    end
    
    def path(dir, *paths)
      each do |env|
        path = env.root.path(dir, *paths)
        return path if !block_given? || yield(path)
      end
      nil
    end
    
    # Retrieves a path associated with the inheritance hierarchy of an object.
    # An array of modules (which naturally can include classes) are provided
    # and module_path traverses each, forming paths like: 
    #
    #   path(dir, module_path, *paths)
    #
    # By default, 'module_path' is 'module.to_s.underscore', but modules can
    # specify an alternative by providing a module_path method.
    #
    # The paths are yielded to the block and when the block returns true,
    # the path will be returned.  If no block is given, the first module path
    # is returned. Returns nil if the block never returns true.
    #
    def module_path(dir, modules, *paths, &block)
      paths.compact!
      while current = modules.shift
        module_path = if current.respond_to?(:module_path)
          current.module_path
        else
          current.to_s.underscore
        end
        
        if path = self.path(dir, module_path, *paths, &block)
          return path
        end
      end
    
      nil
    end
    
    # Returns the module_path traversing the inheritance hierarchy for the
    # class of obj (or obj if obj is a Class).  Included modules are not
    # visited, only the superclasses.
    def class_path(dir, obj, *paths, &block)
      klass = obj.kind_of?(Class) ? obj : obj.class
      superclasses = klass.ancestors - klass.included_modules
      module_path(dir, superclasses, *paths, &block)
    end
    
    # Register an object for lookup by seek.
    def register(type, obj)
      objects = entries(type)
      if objects.include?(obj)
        false
      else
        objects << obj
        true
      end
    end
    
    def register_constant(type, constant)
      const = Constant.new(constant.to_s)
      objects = entries(type)
      if objects.include?(const)
        false
      else
        objects << const
        true
      end
    end
    
    # Returns an array of objects registered to type.  The objects array is
    # extended with Minimap to allow minikey lookup.
    def entries(type)
      objects = registry[type.to_s] ||= []
      unless objects.kind_of?(Minimap)
        objects.extend(Minimap)
      end
      objects
    end
    
    #--
    # Environment-seek
    def eeek(type, key)
      key =~ COMPOUND_KEY
      envs = if $2
        # compound key, match for env
        key = $2
        [minimatch($1)].compact
      else
        # not a compound key, search all envs by iterating self
        self
      end
    
      # traverse envs looking for the first
      # manifest entry matching key
      envs.each do |env|
        result = if block_given? 
          yield(env, key)
        else
          env.entries(type).minimatch(key)
        end
        
        return [env, result] if result
      end
    
      nil
    end
    
    # Searches across each for the first registered object minimatching key. A
    # single env can be specified by using a compound key like 'env_key:key'.
    #
    # Returns nil if no matching object is found.
    def seek(type, key, &block) # :yields: env, key
      env, result = eeek(type, key, &block)
      result
    end
    
    # Creates a manifest with entries defined by the return of the block.  The
    # manifest will be cached in manifests if a key is provided.
    def manifest(type, klass=Manifest, &builder) # :yields: env 
      klass.new(self, type, &builder)
    end
    
    def constant_manifest(key)
      key = key.to_s
      manifests[key] ||= manifest(key, Env::ConstantManifest) do |env|
        paths = []
        env.load_paths.each do |load_path|
          pattern = File.join(load_path, '**/*.rb')
          Dir.glob(pattern).each do |path|
            relative_path = Tap::Root::Utils.relative_path(load_path, path)
            paths << [relative_path, path]
          end
        end
        
        paths.uniq!
        paths.sort!
        paths
      end
      
      ###############################################################
      # [depreciated] manifest as a task key will be removed at 1.0
      if key == 'task'
        manifests[key].const_attr = /task|manifest/
      end
      manifests[key]
      ###############################################################
    end
    
    def [](key)
      constant_manifest(key)
    end
    
    # All templaters are yielded to the block before any are built.  This
    # allows globals to be determined for all environments.
    def inspect(template=nil, globals={}, filename=nil) # :yields: templater, globals
      if template == nil
        return "#<#{self.class}:#{object_id} root='#{root.root}'>" 
      end
      
      env_keys = minihash(true)
      collect do |env|
        templater = Support::Templater.new(template, :env => env, :env_key => env_keys[env])
        yield(templater, globals) if block_given? 
        templater
      end.collect! do |templater|
        templater.build(globals, filename)
      end.join
    end
    
    protected
    
    # returns the env cached for path, if it exists (used to prevent infinite nests)
    def cached_env(path) # :nodoc:
      (cache[:env] ||= []).find {|env| env.root.root == path }
    end
    
    # resets envs using the current env_paths and gems.  does nothing
    # until both env_paths and gems are set.
    def reset_envs # :nodoc:
      if env_paths && gems
        self.envs = env_paths.collect do |path| 
          cached_env(path) || Env.new(path, basename, cache)
        end + gems.collect do |spec|
          cached_env(spec.full_gem_path) || Env.from_gemspec(spec, basename, cache)
        end
      end
    end
  
    # arrayifies, compacts, and resolves input paths using root, and
    # removes duplicates.  in short:
    #
    #   resolve_paths ['lib', nil, 'lib', 'alt]  # => [root['lib'], root['alt']]
    #
    def resolve_paths(paths) # :nodoc:
      paths = yaml_load(paths) if paths.kind_of?(String)
      [*paths].compact.collect {|path| root[path] }.uniq
    end
  
    # helper to recursively iterate through envs, starting with self.
    # visited envs are collected in order and are used to ensure a
    # given env will only be visited once.
    def visit_envs(visited=[], &block) # :nodoc:
      unless visited.include?(self)
        visited << self
        yield(self) if block_given?
      
        envs.each do |env|
          env.visit_envs(visited, &block)
        end
      end
    
      visited
    end
  
    # helper to recursively inject a memo to the children of env
    def inject_envs(memo, visited=[], &block) # :nodoc:
      unless visited.include?(self)
        visited << self
        next_memo = yield(memo, self)
        envs.each do |env|
          env.inject_envs(next_memo, visited, &block)
        end
      end
    
      visited
    end
    
    private
    
    # A 'quick' yaml load where empty strings will not cause YAML to autoload.
    # This is a silly song and dance, but provides for optimal launch times.
    def yaml_load(str) # :nodoc:
      str.empty? ? false : YAML.load(str) 
    end
    
    # Raised when there is a configuration error from Env.load_config.
    class ConfigError < StandardError # :nodoc:
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
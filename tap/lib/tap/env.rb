require 'tap/root'
require 'tap/env/manifest'
require 'tap/templater'
autoload(:YAML, 'yaml')

module Tap
  # Env abstracts an execution environment that spans many directories.
  class Env
    autoload(:Gems, 'tap/env/gems')
  
    class << self
      attr_writer :instance
      
      def instance(auto_initialize=true)
        @instance ||= (auto_initialize ? setup : nil)
      end
      
      def setup(options={}, env_vars=ENV)
        options = {
          :dir => Dir.pwd,
          :config_file => CONFIG_FILE
        }.merge(options)

        # load configurations
        dir = options.delete(:dir)
        config_file = options.delete(:config_file)
        user_config_file = config_file ? File.join(dir, config_file) : nil

        user = load_config(user_config_file)
        global = {}
        env_vars.each_pair do |key, value|
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
        env = new(config, :basename => config_file)
        
        # add the tap env if necessary
        unless env.any? {|e| e.root.root == TAP_HOME }
          env.push new(TAP_HOME, env.context) 
        end

        env
      end
      
      def from_gemspec(spec, context={})
        path = spec.full_gem_path
        basename = context[:basename]
        
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
          'root' => path,
          'gems' => dependencies,
          'load_paths' => spec.require_paths,
          'set_load_paths' => false
        }
        
        if context[:basename]
          config.merge!(Env.load_config(File.join(path, context[:basename])))
        end
        
        new(config, context)
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
      
      def scan_dir(load_path, pattern='**/*.rb')
        Dir.chdir(load_path) do 
          Dir.glob(pattern).each do |require_path|
            next unless File.file?(require_path)

            default_const_name = require_path.chomp('.rb').camelize
            
            # note: the default const name has to be set here to allow for implicit
            # constant attributes. An error can arise if the same path is globed
            # from two different dirs... no surefire solution.
            Lazydoc[require_path].default_const_name = default_const_name
            
            # scan for constants
            Lazydoc::Document.scan(File.read(require_path)) do |const_name, type, comment|
              const_name = default_const_name if const_name.empty?
              constant = Constant.new(const_name, require_path, comment)
              yield(type, constant)
              
              ###############################################################
              # [depreciated] manifest as a task key will be removed at 1.0
              if type == 'manifest'
                warn "depreciation: ::task should be used instead of ::manifest as a resource key (#{require_path})"
                yield('task', constant)
              end
              ###############################################################
            end
          end
        end
      end
      
      def scan(path, key='[a-z_]+')
        Lazydoc::Document.scan(File.read(path), key) do |const_name, type, comment|
          if const_name.empty?
            unless const_name = Lazydoc[path].default_const_name
              raise "could not determine a constant name for #{type} in: #{path.inspect}"
            end
          end
          
          constant = Constant.new(const_name, path, comment)
          yield(type, constant)
          
          ###############################################################
          # [depreciated] manifest as a task key will be removed at 1.0
          if type == 'manifest'
            warn "depreciation: ::task should be used instead of ::manifest as a resource key (#{require_path})"
            yield('task', constant)
          end
          ###############################################################
        end
      end
    end
    self.instance = nil
    
    include Enumerable
    include Configurable
    include Minimap
    
    # The config file path
    CONFIG_FILE = "tap.yml"
    
    # The home directory for Tap
    TAP_HOME = File.expand_path("#{File.dirname(__FILE__)}/../..")
    
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
    
    attr_reader :context
    
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
    def initialize(config_or_dir=Dir.pwd, context={})
      @active = false
      @manifests = {}
      @context = context
      
      # setup root
      config = nil
      @root = case config_or_dir
      when Root   then config_or_dir
      when String then Root.new(config_or_dir)
      else
        config = config_or_dir
        
        if config.has_key?(:root) && config.has_key?('root')
          raise "multiple values mapped to :root"
        end
        
        root = config.delete(:root) || config.delete('root') || Dir.pwd
        root.kind_of?(Root) ? root : Root.new(root)
      end
      
      if basename && !config
        config = Env.load_config(File.join(@root.root, basename))
      end
      
      if instance(@root.root)
        raise "context already has an env for: #{@root.root}"
      end
      instances << self
      
      # set these for reset_env
      @gems = nil
      @env_paths = nil
      initialize_config(config || {})
    end
    
    # The minikey for self (root.root).
    def minikey
      root.root
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
    
    def registry(build=false)
      builders.each_pair do |type, builder|
        registry[type] ||= builder.call(self)
      end if build
      
      registries[minikey] ||= begin
        registry = {}
        load_paths.each do |load_path|
          next unless File.directory?(load_path)
          
          Env.scan_dir(load_path) do |type, constant|
            (registry[type.to_sym] ||= []) << constant
          end
        end
        
        registry
      end
    end
    
    # block should return an array of entries, for example:
    #
    #   env.register('type', true) { [Tap::Env::Constant.new(Class.to_s)] }
    #
    #--
    # Note this is non-ideal because the registries have to be built
    # before a type is registered... making this expensive
    def register(type, override=false, &block) # :yields: env
      type = type.to_sym
      
      # error for existing, or overwrite
      case
      when override
        builders.delete(type)
        each {|env| env.registry.delete(type) }
      when builders.has_key?(type)
        raise "a builder is already registered for: #{type.inspect}"
      when any? {|env| env.registry.has_key?(type) }
        raise "entries are already registered for: #{type.inspect}"
      end
      
      builders[type] = block
    end
    
    #--
    # Potential bug, constants can be added twice.
    def scan(path, key='[a-z_]+')
      registry = self.registry
      Env.scan(path, key) do |type, constant|
        (registry[type.to_sym] ||= []) << constant
      end
    end
    
    def manifest(type) # :yields: env
      type = type.to_sym
      
      registry[type] ||= begin
        builder = builders[type]
        builder ? builder.call(self) : []
      end
      
      manifests[type] ||= Manifest.new(self, type)
    end
    
    def [](type)
      manifest(type)
    end
    
    def reset
      manifests.clear
      registries.clear
    end
    
    # Searches across each for the first registered object minimatching key. A
    # single env can be specified by using a compound key like 'env_key:key'.
    #
    # Returns nil if no matching object is found.
    def seek(type, key, value_only=true)
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
        if value = env.manifest(type).minimatch(key)
          return value_only ? value : [env, value]
        end
      end
    
      nil
    end
    
    def reverse_seek(type, key_only=true, &block)
      each do |env|
        manifest = env.manifest(type)
        if value = manifest.find(&block)
          key = manifest.minihash(true)[value]
          return key_only ? key : "#{minihash(true)[env]}:#{key}"
        end
      end
    
      nil
    end
    
    # All templaters are yielded to the block before any are built.  This
    # allows globals to be determined for all environments.
    def inspect(template=nil, globals={}, filename=nil) # :yields: templater, globals
      if template == nil
        return "#<#{self.class}:#{object_id} root='#{root.root}'>" 
      end
      
      env_keys = minihash(true)
      collect do |env|
        templater = Templater.new(template, :env => env, :env_key => env_keys[env])
        yield(templater, globals) if block_given? 
        templater
      end.collect! do |templater|
        templater.build(globals, filename)
      end.join
    end
    
    protected
    
    def registries # :nodoc:
      context[:registries] ||= {}
    end
    
    def basename # :nodoc:
      context[:basename]
    end
    
    def builders # :nodoc:
      context[:builders] ||= {}
    end
    
    def instances # :nodoc:
      context[:instances] ||= []
    end
    
    def instance(path) # :nodoc:
      instances.find {|env| env.root.root == path }
    end
    
    # resets envs using the current env_paths and gems.  does nothing
    # until both env_paths and gems are set.
    def reset_envs # :nodoc:
      if env_paths && gems
        self.envs = env_paths.collect do |path| 
          instance(path) || Env.new(path, context)
        end + gems.collect do |spec|
          instance(spec.full_gem_path) || Env.from_gemspec(spec, context)
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
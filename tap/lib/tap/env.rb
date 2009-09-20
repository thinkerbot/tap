require 'tap/root'
require 'tap/env/constant'
require 'tap/env/context'
require 'tap/env/manifest'
require 'tap/templater'
autoload(:YAML, 'yaml')

module Tap
  
  # == Description
  #
  # Env provides access to an execution environment spanning many directories,
  # such as the working directory and a series of gem directories.  Envs merge
  # the files from each directory into an abstract directory that may be 
  # globbed and accessed as a single unit.  For example:
  #
  #   # /one
  #   # |-- a.rb
  #   # `-- b.rb
  #   #
  #   # /two
  #   # |-- b.rb
  #   # `-- c.rb
  #   env =  Env.new('/one')
  #   env << Env.new('/two')
  #
  #   env.collect {|e| e.root.root}
  #   # => ["/one", "/two"]
  #
  #   env.glob(:root, "*.rb")
  #   # => [
  #   # "/one/a.rb",
  #   # "/one/b.rb",
  #   # "/two/c.rb"
  #   # ]
  # 
  # As illustrated, files in the nested environment are accessible within the
  # nesting environment. Envs provide methods for finding files associated
  # with a specific class, and allow the generation of manifests that provide
  # succinct access to various environment resources.
  #
  # Usage of Envs is fairly straightforward, but the internals and default
  # setup require some study as they have to span numerous functional domains.
  # The most common features are detailed below.
  #
  # ==== Class Paths
  #
  # Class paths are a kind of inheritance for files associated with a class.
  # Say we had the following classes:
  #
  #   class A; end
  #   class B < A; end
  #
  # The naturally associated directories are 'a' and 'b'.  To look these up:
  #
  #   env.class_path(:root, A)    # => "/one/a"
  #   env.class_path(:root, B)    # => "/one/b"
  #
  # And to look up an associated file:
  # 
  #   env.class_path(:root, A, "index.html") # => "/one/a/index.html"
  #   env.class_path(:root, B, "index.html") # => "/one/b/index.html"
  #
  # More significantly a block may be given to filter paths, for instance to
  # test if a given file exists.  The class_path method will check each env
  # then roll up the inheritance hierarchy until the block returns true.  
  #
  #   FileUtils.touch("/two/a/index.html")
  #
  #   visited_paths = []
  #   env.class_path(:root, B, "index.html) do |path|
  #     visited_paths << path
  #     File.exists?(path)
  #   end                         # => "/two/a/index.html"
  #
  #   visited_paths
  #   # => [
  #   # "/one/b/index.html",
  #   # "/two/b/index.html",
  #   # "/one/a/index.html",
  #   # "/two/a/index.html"
  #   # ]
  #
  # This behavior is very useful for associating views with a class.
  #
  # ==== Manifest
  #
  # Envs can generate manifests of various resources so they may be identified
  # using minipaths (see Minimap for details regarding minipaths).  Command
  # files used by the tap executable are one example of a resource, and the
  # constants used in building a workflow are another.
  #
  # Manifest are generated by defining a builder, typically a block, that
  # receives an env and returns an array of the associated resources.
  # Using the same env as above:
  #
  #   manifest = env.manifest {|e| e.root.glob(:root, "*.rb") }
  #
  #   manifest.seek("a")          # => "/one/a.rb"
  #   manifest.seek("b")          # => "/one/b.rb"
  #   manifest.seek("c")          # => "/two/c.rb"
  #
  # As illustrated, seek finds the first entry across all envs that matches the
  # input minipath.  A minipath for the env may be prepended to only search
  # within a specific env.
  #
  #   manifest.seek("one:b")      # => "/one/b.rb"
  #   manifest.seek("two:b")      # => "/two/b.rb"
  #
  # == Setup
  #
  # Envs may be manually setup in code by individually generating instances
  # and nesting them.  More commonly envs are defined in configuration files
  # and instantiated by specifying where the files are located.  The default
  # config basename is 'tap.yml'; any env_paths specified in the config file
  # will be added.
  #
  # This type of instantiation is recursive:
  #
  #   # [/one/tap.yml]
  #   # env_paths: [/two]
  #   #
  #   # [/two/tap.yml]
  #   # env_paths: [/three]
  #   #
  #
  #   env = Env.new("/one", :basename => 'tap.yml')
  #   env.collect {|e| e.root.root}
  #   # => ["/one", "/two", "/three"]
  #
  # Gem directories are fair game.  Env allows specific gems to be specified
  # by name (via the 'gems' config), and if a gem has a tap.yml file then it
  # will be used to configure the gem env.  Alternatively, an env may be set
  # to automatically discover and nest gem environments.  In this case gems
  # are discovered when they have a tap.yml file.
  # 
  # ==== ENV configs
  #
  # Configurations may be also specified as an ENV variables. This type of
  # configuration is very useful on the command line. Config variables
  # should be prefixed by TAP_ and named like the capitalized config key 
  # (ex: TAP_GEMS or TAP_ENV_PATHS).  See the 
  # {Command Line Examples}[link:files/doc/Examples/Command%20Line.html]
  # to see ENV configs in action.
  #
  # These configurations may be accessed from Env#config, and are
  # automatically incorporated by Env#setup.
  #
  class Env
    autoload(:Gems, 'tap/env/gems')
  
    class << self
      
      # Returns the Env configs specified in ENV.  Config variables are
      # prefixed by TAP_ and named like the capitalized config key 
      # (ex: TAP_GEMS or TAP_ENV_PATHS).
      def config(env_vars=ENV)
        config = {}
        env_vars.each_pair do |key, value|
          if key =~ /\ATAP_(.*)\z/
            config[$1.downcase] = value
          end
        end
        config
      end
      
      # Initializes and activates an env as described in the config file under
      # dir. The config file should be a relative path and will be used for
      # determining configuration files under each env_path.
      #
      # The env configuration is determined by merging the following in order:
      # * defaults {root => dir, gems => all}
      # * ENV configs
      # * config_file configs
      #
      # The HOME directory for Tap will be added as an additonal environment
      # if not already added somewhere in the env hierarchy.  By default all
      # gems will be included in the Env.
      def setup(dir=Dir.pwd, config_file=CONFIG_FILE)
        # setup configurations
        config = {'root' => dir, 'gems' => :all}
        
        user_config_file = config_file ? File.join(dir, config_file) : nil
        user = load_config(user_config_file)
        
        config.merge!(self.config)
        config.merge!(user)
        
        # keys must be symbolized as they are immediately 
        # used to initialize the Env configs
        config = config.inject({}) do |options, (key, value)|
          options[key.to_sym || key] = value
          options
        end
        
        # instantiate
        context = Context.new(:basename => config_file)
        env = new(config, context)
        
        # add the tap env if necessary
        unless env.any? {|e| e.root.root == HOME }
          env.push new(HOME, context) 
        end
        
        env.activate
        env
      end
      
      # Generates an Env for the specified gem or Gem::Specification.  The
      # gemspec for the gem is used to determine the env configuration in
      # the following way:
      #
      #   root: the gem path
      #   gems: all gem dependencies with a config_file
      #   load_paths: the gem require paths
      #   set_load_paths: false (because RubyGems sets them for you)
      #
      # Configurations specified in the gem config_file override these
      # defaults.
      def setup_gem(gem_name, context=Context.new)
        spec = Gems.gemspec(gem_name)
        path = spec.full_gem_path
        
        # determine gem dependencies that have a config_file;
        # these will be set as the gems for the new Env
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
          
          if config_file = context.config_file(gemspec.full_gem_path)
            next unless File.exists?(config_file)
          end
          
          dependencies << gemspec
        end
        
        config = {
          'root' => path,
          'gems' => dependencies,
          'load_paths' => spec.require_paths,
          'set_load_paths' => false
        }
        
        # override the default configs with whatever configs
        # are specified in the gem config file
        if config_file = context.config_file(path)
          config.merge!(load_config(config_file))
        end
        
        new(config, context)
      end
      
      # Loads configurations from path as YAML.  Returns an empty hash if the path
      # loads to nil or false (as happens for empty files), or doesn't exist.
      #
      # Raises a ConfigError if the configurations do not load properly.
      def load_config(path)
        return {} unless path
        
        begin
          Root::Utils.trivial?(path) ? {} : (YAML.load_file(path) || {})
        rescue(Exception)
          raise ConfigError.new($!, path)
        end
      end
    end
    
    include Configurable
    include Enumerable
    include Minimap
    
    # The config file path
    CONFIG_FILE = "tap.yml"
    
    # The home directory for Tap
    HOME = File.expand_path("#{File.dirname(__FILE__)}/../..")
    
    # An array of nested Envs, by default comprised of the env_path
    # + gem environments (in that order).  Envs can be manually set
    # to override these defaults.
    attr_reader :envs
    
    # A Context tracking information shared among a set of envs.
    attr_reader :context
    
    # The Root directory structure for self.
    nest(:root, Root, :init => false)
  
    # Specify gems to add as nested Envs.  Gems may be specified by name
    # and/or version, like 'gemname >= 1.2'; by default the latest version
    # of the gem is selected. 
    #
    # Several special values also exist:
    #
    #   :NONE, :none   indicates no gems (same as nil, false)
    #   :LATEST        the latest version of all gems
    #   :ALL           all gems
    #   :latest        the latest version of all gems with a config file
    #   :all           all gems with a config file
    #
    # Gems are not activated by Env.
    config_attr :gems, [] do |input|
      input = yaml_load(input) if input.kind_of?(String)
      
      @gems = case input
      when false, nil, :NONE, :none
        []
      when :LATEST, :ALL
        # latest and all, no filter
        Gems.select_gems(input == :LATEST)
      when :latest, :all
        # latest and all, filtering by the existence of a
        # config file; all gems are selected if no config
        # file can be determined.
        Gems.select_gems(input == :latest) do |spec|
          config_file = context.config_file(spec.full_gem_path)
          config_file == nil || File.exists?(config_file)
        end
      else
        # resolve gem names manually
        [*input].collect do |name|
          Gems.gemspec(name)
        end.compact
      end
    
      reset_envs
    end

    # Specify directories to load as nested Envs.  Configurations for the
    # env are loaded from the config file under dir, if it exists.
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
    
    # Initializes a new Env linked to the specified directory.  Configurations
    # for the env will be loaded from the config file (as determined by the
    # context) if it exists.
    #
    # A configuration hash may be manually provided in the place of dir.  In
    # that case, no configurations will be loaded, even if the config file
    # exists.
    #
    # Context can be specified as a Context, or a Hash used to initialize a
    # Context.
    def initialize(config_or_dir=Dir.pwd, context={})
      
      # setup root
      config = nil
      @root = case config_or_dir
      when Root
        config_or_dir
      when String
        Root.new(config_or_dir)
      else
        config = config_or_dir
        
        if config.has_key?(:root) && config.has_key?('root')
          raise "multiple values mapped to :root"
        end
        
        root = config.delete(:root) || config.delete('root') || Dir.pwd
        root.kind_of?(Root) ? root : Root.new(root)
      end
      
      # note registration requires root.root, and so the
      # setup of context must follow the setup of root.
      @context = case context
      when Context
        context
      when Hash
        Context.new(context)
      else raise "cannot convert #{context.inspect} to Tap::Env::Context"
      end
      @context.register(self)
      
      # these need to be set for reset_env
      @active = false
      @gems = nil
      @env_paths = nil
      
      # only load configurations if configs were not provided
      config ||= Env.load_config(@context.config_file(@root.root))
      initialize_config(config)
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
    alias_method :<<, :push
  
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
    # * activate nested environments
    # * unshift load_paths to $LOAD_PATH (if set_load_paths is true)
    #
    # Once active, the current envs and load_paths are frozen and cannot be
    # modified until deactivated. Returns true if activate succeeded, or
    # false if self is already active.
    def activate
      return false if active?
      
      @active = true
      
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
    #
    # Once deactivated, envs and load_paths are unfrozen and may be modified.
    # Returns true if deactivate succeeded, or false if self is not active.
    #
    # ==== Note
    # 
    # Deactivation does not necessarily leave $LOAD_PATH in the same condition
    # as before activation.  A pre-existing $LOAD_PATH entry can go missing if
    # it is also registered as an env load_path (deactivation doesn't know to
    # leave such paths alone).
    #
    # Deactivation, like constant unloading should be done with caution.
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
      
      true
    end
    
    # Return true if self has been activated.
    def active?
      @active
    end
    
    # Globs the abstract directory for files in the specified directory alias,
    # matching the pattern.  The expanded path of each matching file is
    # returned.
    def glob(dir, pattern="**/*")
      hlob(dir, pattern).values.sort!
    end
    
    # Same as glob but returns results as a hash of (relative_path, path)
    # pairs.  In short the hash defines matching files in the abstract
    # directory, linked to the actual path for these files.
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
    
    # Returns the path to the specified file, as determined by root.
    #
    # If a block is given, a path for each env will be yielded until the block
    # returns a true value.  Returns nil if the block never returns true.
    def path(dir = :root, *paths)
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
    # By default 'module_path' is 'module.to_s.underscore' but modules can
    # specify an alternative by providing a module_path method.
    #
    # Paths are yielded to the block until the block returns true, at which
    # point the current the path is returned.  If no block is given, the
    # first path is returned. Returns nil if the block never returns true.
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
    
    # Generates a Manifest for self using the block as a builder.  The builder
    # receives an env and should return an array of resources, each of which
    # can be minimappped.  Minimapping requires that the resource is either
    # a path string, or provides a 'path' method that returns a path string.
    # Alternatively, a Minimap may be returned.
    #
    # If a type is specified, then the manifest cache will be linked to the
    # context cache.
    def manifest(type=nil, &block) # :yields: env
      cache = type ? (context.cache[type] ||= {}) : {}
      Manifest.new(self, block, cache)
    end
    
    # Returns a manifest of Constants located in .rb files under each of the
    # load_paths. Constants are identified using Lazydoc constant attributes;
    # all attributes are registered to the constants for classification
    # (for example as a task, join, etc).
    def constants
      @constants ||= manifest(:constants) do |env|
        constants = Hash.new do |hash, const_name|
          hash[const_name] = Constant.new(const_name)
        end

        env.load_paths.each do |load_path|
          next unless File.directory?(load_path)

          # note changing dir here makes require paths relative to load_path,
          # hence they can be directly converted into a default_const_name
          # rather than first performing Root.relative_path
          Dir.chdir(load_path) do 
            Dir.glob("**/*.rb").each do |path| 
              default_const_name = path.chomp('.rb').camelize

              # scan for constants
              Lazydoc::Document.scan(File.read(path)) do |const_name, type, summary|
                const_name = default_const_name if const_name.empty?

                constant = constants[const_name]
                constant.register_as(type, summary)
                constant.require_paths << path
              end
            end
          end
        end

        constants.keys.sort!.collect! do |key| 
          constants[key]
        end
      end
    end
    
    # Seeks and constantizes the specified constant.  Raises an error if the
    # key does not map to a constant.
    def [](key)
      unless constant = constants.seek(key)
        raise "unresolvable constant: #{key.inspect}"
      end
      constant.constantize
    end
    
    # When no template is specified, inspect generates a fairly standard
    # inspection string.  When a template is provided, inspect builds a
    # Templater for each env with the following local variables:
    #
    #   variable    value
    #   env         the current env
    #   env_keys    a minihash for all envs
    #
    # If a block is given, the globals and templater are yielded before
    # any templater is built; this allows each env to add env-specific
    # variables.  After this preparation, each templater is built with
    # the globals and the results concatenated.
    #
    # The template is built with filename, if specified (for debugging).
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
    
    # helper for Minimap; note that specifying env.root.root via path
    # is not possible because path is required for other purposes.
    def entry_to_path(env) # :nodoc:
      env.root.root
    end
    
    # resets envs using the current env_paths and gems.  does nothing
    # until both env_paths and gems are set.
    def reset_envs # :nodoc:
      if env_paths && gems
        self.envs = env_paths.collect do |path| 
          context.instance(path) || Env.new(path, context)
        end + gems.collect do |spec|
          context.instance(spec.full_gem_path) || Env.setup_gem(spec, context)
        end
      end
    end
  
    # arrayifies, compacts, and resolves input paths using root.
    # also removes duplicates.  in short:
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
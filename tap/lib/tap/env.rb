require 'tap/root'
require 'tap/env/minimap'
require 'tap/env/constant'
require 'tap/env/context'
require 'tap/templater'
autoload(:YAML, 'yaml')

module Tap
  
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
  #   # "/one/a.rb"
  #   # "/one/b.rb"
  #   # "/two/c.rb"
  #   # ]       
  # 
  # As illustrated, files in the nested environment are accessible within the
  # nesting environment. Envs provide additional methods for finding files
  # associated with a specific class.
  #
  class Env
    autoload(:Gems, 'tap/env/gems')
  
    class << self
      
      # Initializes the Env used by the tap executable.  The Env will be
      # configured as described in the tap.yml file for the working directory.
      # By default all gems will be included in the Env.
      #
      # The options hash can be used to specify an alternative dir/config_file,
      # as well as overridding Env configs:
      #
      #   key            meaning
      #   :dir           specifies the working directory
      #   :config_file   specifies the config file
      #   ... overridding configs ...
      #
      # Configurations may be also specified as an ENV variables.  The variable
      # should be prefixed by TAP_ and named like the capitalized config key 
      # (ex: TAP_GEMS or TAP_ENV_PATHS).
      #
      # ==== Specific Details
      #
      # Configurations are determined by merging the following in order:
      # * defaults {root => pwd, gems => all}
      # * ENV configs
      # * config_file configs
      # * configs in options
      # 
      # The dir/config_file options will not be added as configurations. The
      # HOME directory for Tap will be added as an additonal environment if
      # not already added somewhere in the env hierarchy.
      #
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

        # keys must be symbolized as they are immediately 
        # used to initialize the Env configs
        config = config.inject({}) do |options, (key, value)|
          options[key.to_sym || key] = value
          options
        end

        # instantiate
        env = new(config, :basename => config_file)
        
        # add the tap env if necessary
        unless env.any? {|e| e.root.root == HOME }
          env.push new(HOME, env.context) 
        end
        
        env.activate
        env
      end
      
      # Generates an Env from a Gem::Specification.
      def from_gemspec(spec, context={})
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
        
        if config_file = context.config_file(path)
          config.merge!(Env.load_config(config_file))
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
      
      def scan(load_path, pattern='**/*.rb')
        docs = []
        
        # note changing dir here makes require paths relative to load_path,
        # hence they can be directly converted into a default_const_name
        # rather than first performing Root.relative_path
        Dir.chdir(load_path) do 
          Dir.glob(pattern).each do |path| 
            next unless File.file?(path)
            
            default_const_name = path.chomp('.rb').camelize
          
            if doc = Lazydoc.document(source_file)
              # note: the default const name has to be set here to allow for implicit
              # constant attributes. An error can arise if the same path is globed
              # from two different dirs... no surefire solution.
              if doc.default_const_name != default_const_name
                raise "conflicting default constant name"
              end
            else
              doc = Lazydoc.register_file(source_file, default_const_name)
              
              # scan for constants
              Lazydoc::Document.scan(File.read(path)) do |const_name, key, value|
                comment = (doc[const_name][key] ||= Subject.new(nil, doc))
                comment.subject = value
              end
              
              ###############################################################
              # [depreciated] manifest as a task key will be removed at 1.0
              if key == 'manifest'
                warn "depreciation: ::task should be used instead of ::manifest as a resource key (#{require_path})"
              end
              ###############################################################
            end
            
            docs << doc
          end
        end
        
        constants = []
        Lazydoc::Document.const_attrs.each_pair do |constant, comments|
          comments.each do |key, comment|
            if docs.include?(comment.document)
              constants << constant
            end
          end
        end
        
        constants
      end
    end
    
    include Enumerable
    include Configurable
    include Minimap
    
    # The config file path
    CONFIG_FILE = "tap.yml"
    
    # The home directory for Tap
    HOME = File.expand_path("#{File.dirname(__FILE__)}/../..")
    
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
    
    # The Root directory structure for self.
    nest(:root, Root, :set_default => false)
  
    # Specify gems to add as nested Envs.  Gems may be specified by name
    # and/or version, like 'gemname >= 1.2'; by default the latest version
    # of the gem is selected.  Gems are not activated by Env.
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
      
      # setup context
      @context = case context
      when Hash
        Context.new(context) 
      when Context
        context
      else
        raise "cannot convert #{context.class} to Tap::Env::Context"
      end
      
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
      
      config ||= Env.load_config(@context.config_file(@root.root))
      @context.register(self)
      
      # set these for reset_env
      @gems = nil
      @env_paths = nil
      initialize_config(config || {})
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
    
    # Globs the abstract directory for files in the specified directory alias,
    # matching the pattern.  The expanded path of each matching file is
    # returned.
    def glob(dir, pattern="**/*")
      hlob(dir, pattern).values.sort!
    end
    
    # Returns the path to the specified file.  The path is returned for
    # relative to root, regardless of whether the file exists in the abstract
    # directory or not.
    #
    # If a block is given, the path relative to each env will be yielded unti
    # the block returns a true value.  Returns nil if the block never returns
    # true.
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
    
    def register(type, &block) # :yields: env
      context.manifests[type] = block
    end
    
    def manifest(type)
      cache[type] ||= context.manifests[type].call(self).extend(Minimap)
    end
    
    def [](key)
      seek(:constant, key).constantize
    end
    
    # Searches across each for the first registered constant minimatching key. A
    # single env can be specified by using a compound key like 'env_key:key'.
    #
    # Returns nil if no matching constant is found.
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

    def reverse_seek(type, value, key_only=true)
      each do |env|
        objects = env.manifest(type)
        if object = objects.find {|obj| obj == value }
          key = objects.minihash(true)[object]
          return key_only ? key : "#{minihash(true)[env]}:#{key}"
        end
      end
      
      nil
    end
    
    SUMMARY_TEMPLATE = %Q{<% if !entries.empty? && count > 1 %>
<%= env_key %>:
<% end %>
<% entries.each do |key, entry| %>
  <%= key.ljust(width) %> # <%= entry %>
<% end %>
}

    def summarize(type, template=SUMMARY_TEMPLATE)
      inspect(template, :width => 11, :count => 0) do |templater, globals|
        width = globals[:width]

        entries = templater.env.manifest(type).minimap
        
        if block_given?
          entries.collect! do |key, entry| 
            entry = yield(entry)
            entry ? [key, entry] : nil
          end
          entries.compact! 
        end
        
        entries.each do |key, entry|
          width = key.length if width < key.length
        end

        globals[:width] = width
        globals[:count] += 1 unless entries.empty?

        templater.entries = entries
      end
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
    
    def cache # :nodoc:
      context.cache(self)
    end
    
    # helper for Minimap
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
          context.instance(spec.full_gem_path) || Env.from_gemspec(spec, context)
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
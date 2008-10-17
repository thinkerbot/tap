require 'tap/support/constant_manifest'
require 'tap/support/gems'

module Tap

  #--
  # Note that gems and env_paths reset envs -- custom modifications to envs will be lost
  # whenever these configs are reset.
  class Env
    include Support::Configurable
    include Support::Manifestable
    
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
      # load_config, and a Root initialized to the config file directory. An instance 
      # will be initialized regardless of whether the config file or directory exists.
      def instantiate(path_or_root, default_config={}, logger=nil, &block)
        path = path_or_root.kind_of?(Root) ? path_or_root.root : path_or_root
        path = pathify(path)
        
        begin
          root = path_or_root.kind_of?(Root) ? path_or_root : Root.new(File.dirname(path))
          config = default_config.merge(load_config(path))
          
          # note the assignment of env to instances MUST occur before
          # reconfigure to prevent infinite looping
          (instances[path] = new({}, root, logger)).reconfigure(config, &block)
        rescue(Exception)
          raise Env::ConfigError.new($!, path)
        end
      end
      
      def instance_for(path)
        path = pathify(path)
        instances.has_key?(path) ? instances[path] : instantiate(path)
      end
      
      def pathify(path)
        if File.directory?(path) || (!File.exists?(path) && File.extname(path) == "")
          path = File.join(path, DEFAULT_CONFIG_FILE) 
        end
        File.expand_path(path)
      end
      
      def manifest(name, &block) # :yields: env (returns manifest)
        name = name.to_sym
        define_method(name) do
          self.manifests[name] ||= block.call(self)
        end
      end
      
      def path_manifest(name, paths_key, pattern="**/*.rb", &block)
        manifest_class = Support::Manifest
        if block_given?
          manifest_class = Class.new(manifest_class)
          manifest_class.module_eval(&block)
        end
        
        manifest(name) do |env|
          entries = []
          env.send(paths_key).each do |path_root|
            entries.concat env.root.glob(path_root, pattern)
          end
          
          entries = entries.sort_by {|path| File.basename(path) }
          manifest_class.new(entries)
        end
      end
      
      def const_manifest(name, paths_key, const_attr, pattern="**/*.rb", &block)
        manifest_class = Support::ConstantManifest
        if block_given?
          manifest_class = Class.new(manifest_class)
          manifest_class.module_eval(&block)
        end
        
        manifest(name) do |env|
          paths = env.send(paths_key).collect do |path_root|
            [path_root, env.root.glob(path_root, pattern)]
          end
          
          manifest_class.new(paths, const_attr) 
        end
      end
      
      # Returns the gemspecs for all installed gems with a DEFAULT_CONFIG_FILE. 
      # If latest==true, then only the specs for the most current gems will be 
      # returned.
      def gemspecs(latest=true)
        Support::Gems.select_gems(latest) do |spec|
          File.exists?(File.join(spec.full_gem_path, DEFAULT_CONFIG_FILE))
        end
      end
      
      protected
      
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
    end
    
    @@instance = nil
    @@instances = {}

    # The default config file path
    DEFAULT_CONFIG_FILE = "tap.yml"
    
    # The Root directory structure for self.
    attr_reader :root
    
    # Gets or sets the logger for self
    attr_accessor :logger
    
    # A hash of the manifests for self.
    attr_reader :manifests
    
    # Specify files to require when self is activated.
    config :requires, [], &c.array_or_nil
    
    # Specify files to load when self is activated.
    config :loads, [], &c.array_or_nil
    
    # Specify gems to load as nested Envs.  Gems may be specified 
    # by name and/or version, like 'gemname >= 1.2'; by default the 
    # latest version of the gem is selected.
    #
    # Gems are immediately loaded (via gem) through this method.
    config_attr :gems, [] do |input|
      check_configurable
      specs_by_name = {}
      @gems = [*input].compact.collect do |gem_name| 
        spec = Support::Gems.gemspec(gem_name)
        
        case spec
        when nil then log(:warn, "unknown gem: #{gem_name}", Logger::WARN)
        else Env.instance_for(spec.full_gem_path)
        end
        
        (specs_by_name[spec.name] ||= []) << spec
        spec.name
      end.uniq
      
      # this song and dance is to ensure that the latest spec for a
      # given gem appears first in the manifest
      specs_by_name.each_pair do |name, specs|
        specs_by_name[name] = specs.uniq.sort_by {|spec| spec.version }.reverse
      end
      
      @gems.collect! do |name|
        specs_by_name[name]
      end.flatten!
      
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
    
    # Designate load paths.
    path_config :load_paths, ["lib"]
    
    # Designate paths for discovering and executing commands. 
    path_config :command_paths, ["cmd"]
    
    # Designate paths for discovering generators.  
    path_config :generator_paths, ["lib"]
    
    path_manifest(:commands, :command_paths) 
    
    const_manifest(:tasks, :load_paths, 'manifest')
    
    const_manifest(:generators, :generator_paths, 'generator', '**/*_generator.rb') do
      def minikey(const)
        const.name.underscore.chomp('_generator')
      end
      
      def resolve(path_root, path)
        dirname = File.dirname(path)
        return [] unless File.file?(path) && 
          "#{File.basename(dirname)}_generator.rb" == File.basename(path) && 
          document = Support::Lazydoc.scan_doc(path, 'generator')

        relative_path = Root.relative_filepath(path_root, dirname).chomp(File.extname(path))
        document.default_const_name = "#{relative_path}_generator".camelize
        document.const_names.collect do |const_name|
          Support::Constant.new(const_name, path)
        end
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
    
    # Sets envs removing duplicates and instances of self.
    def envs=(envs)
      @envs = envs.uniq.delete_if {|e| e == self }
      @envs.freeze
      @flat_envs = nil
    end
    
    # An array of nested Envs, by default comprised of the
    # env_path + gem environments (in that order).  These
    # nested Envs are activated/deactivated with self.
    #
    # Returns a flattened array of the unique nested envs
    # when flat == true.
    def envs(flat=false)
      flat ? (@flat_envs ||= self.flatten_envs.freeze) : @envs
    end
    
    # Unshifts env onto envs, removing duplicates.  
    # Self cannot be unshifted onto self.
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
      envs(true).each {|e| yield(e) }
    end
    
    # Passes each nested env to the block in reverse order, ending with self.
    def reverse_each
      envs(true).reverse_each {|e| yield(e) }
    end
    
    # Visits each nested env in order, starting with self, and passing
    # to the block the env and any arguments generated by the parent of 
    # the env.  The initial arguments are set when recursive_each is 
    # first called; subsequent arguements are the return values of the 
    # block.
    #
    #   e0, e1, e2, e3, e4 = ('a'..'e').collect {|name| Tap::Env.new(:name => name) }
    # 
    #   e0.push(e1).push(e2)
    #   e1.push(e3).push(e4)
    # 
    #   lines = []
    #   e0.recursive_each(0) do |env, nesting_depth|
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
    def recursive_each(*args, &block) # :yields: env, *parent_args
      each_nested_env(self, [], args, &block)
    end
    
    # Returns the total number of unique envs nested in self (including self).
    def count
      envs(true).length
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
      @@instance = self if @@instance == nil
      
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

      # add load paths
      load_paths.reverse_each do |path|
        $LOAD_PATH.unshift(path)
      end
    
      $LOAD_PATH.uniq!
      
      # perform requires
      requires.each do |path|
        require path
      end
      
      # perform loads
      loads.each do |path|
        load path
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
      
      # remove load paths
      load_paths.each do |path|
        $LOAD_PATH.delete(path)
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
    
    # Like find, but searches across all envs for the matching value.
    # An env may be specified in key to select a single
    # env to search.
    #
    def search(name, key)
      envs = self.envs(true)
      
      if key =~ /^(.*):([^:]+)$/
        env_key, key = $1, $2
        env = minimatch(env_key)
        return nil unless env
        
        envs = [env]
      end
      
      envs.each do |env|
        if result = env.send(name).minimatch(key)
          return result
        end
      end
      
      nil
    end
    
    # Searches each env for the first existing file or directory at 
    # env.root.filepath(dir, path).  Paths are expanded, and search_path
    # checks to make sure the file is, in fact, relative to env.root[dir].
    # An optional block may be used to check the file; the file will only
    # be returned if the block returns true.
    #
    # Returns nil if no file can be found.
    # def search_path(dir, path)
    #   each do |env|
    #     directory = env.root.filepath(dir)
    #     file = env.root.filepath(dir, path)
    #     
    #     # check the file is relative to the
    #     # directory, and that the file exists.
    #     if file.rindex(directory, 0) == 0 && 
    #       File.exists?(file) && 
    #       (!block_given? || yield(file))
    #       return file
    #     end
    #   end
    #   
    #   nil
    # end
    
    # def reset(name, &block)
    #   each do |env|
    #     env.manifests[name].each(&block)
    #     env.manifests[name] = nil
    #   end
    # end
    
    TEMPLATES = {
      :commands => %Q{<% if count > 1 %>
<%= env_name %>:
<% end %>
<% entries.each do |name, const| %>
  <%= name.ljust(width) %>
<% end %>},

      :tasks => %Q{<% if count > 1 %>
<%= env_name %>:
<% end %>
<% entries.each do |name, const| %>
<%   desc = const.document[const.name]['manifest'] %>
  <%= name.ljust(width) %><%= desc.empty? ? '' : '  # ' %><%= desc %>
<% end %>},

      :generators => %Q{<% if count > 1 %>
<%= env_name %>:
<% end %>
<% entries.each do |name, const| %>
<%   desc = const.document[const.name]['generator'] %>
  <%= name.ljust(width) %><%= desc.empty? ? '' : '  # ' %><%= desc %>
<% end %>}
    }
    
    def summarize(name, template=TEMPLATES[name])
      count = 0
      width = 10
      
      env_names = {}
      minimap.each do |env_name, env|
        env_names[env] = env_name
      end
      
      inspect(template) do |templater, share|
        env = templater.env
        entries = env.send(name).minimap
        next(false) if entries.empty?
        
        templater.env_name = env_names[env]
        templater.entries = entries
        
        count += 1
        entries.each do |entry_name, entry|
          width = entry_name.length if width < entry_name.length
        end
        
        share[:count] = count
        share[:width] = width
        true
      end
    end
    
    def inspect(template=nil) # :yields: templater, attrs
      return "#<#{self.class}:#{object_id} root='#{root.root}'>" if template == nil
      
      attrs = {}
      collect do |env|
        templater = Support::Templater.new(template, :env => env)
        block_given? ? (yield(templater, attrs) ? templater : nil) : templater
      end.compact.collect do |templater|
        templater.build(attrs)
      end.join
    end
    
    def recursive_inspect(template=nil, *args) # :yields: templater, attrs
      return "#<#{self.class}:#{object_id} root='#{root.root}'>" if template == nil
      
      attrs = {}
      templaters = []
      recursive_each(*args) do |env, *argv|
        templater = Support::Templater.new(template, :env => env)
        next_args = block_given? ? yield(templater, attrs, *argv) : argv
        templaters << templater if next_args
        
        next_args
      end
      
      templaters.collect do |templater|
        templater.build(attrs)
      end.join
    end
    
    protected
    
    def minikey(env)
      env.root.root
    end
    
    # Raises an error if self is already active (and hence, configurations
    # should not be modified)
    def check_configurable
      raise "path configurations are disabled when active" if active?
    end
    
    # Resets envs using the current env_paths and gems.
    def reset_envs
      self.envs = env_paths.collect do |path| 
        Env.instance_for(path)
      end + gems.collect do |spec|
        Env.instance_for(spec.full_gem_path)
      end
    end
    
    # Recursively iterates through envs collecting all envs into
    # the target.  The result is a unique array of all nested 
    # envs, in order, beginning with self.
    def flatten_envs(target=[])
      unless target.include?(self)
        target << self
        envs.each do |env|
          env.flatten_envs(target)
        end
      end
      
      target
    end
    
    private
    
    def each_nested_env(env, visited, args, &block)
      return if visited.include?(env)
      
      visited << env
      next_args = yield(env, *args)
      next_args = [] if next_args == nil
      env.envs.each do |nested_env|
        each_nested_env(nested_env, visited, next_args, &block)
      end
    end
    
    # Raised when there is a Env-level configuration error.
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
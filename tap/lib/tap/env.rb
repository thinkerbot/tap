require 'tap/root'
require 'tap/env/manifest'
require 'tap/support/intern'
require 'tap/support/templater'
autoload(:YAML, 'yaml')

module Tap
  # Env abstracts an execution environment that spans many directories.
  class Env
    autoload(:Gems, 'tap/env/gems')
  
    class << self
      
      # Loads configurations from path as YAML.  Returns an empty hash if the path
      # loads to nil or false (as happens for empty files), or doesn't exist.
      def load_config(path)
        begin
          Root::Utils.trivial?(path) ? {} : (YAML.load_file(path) || {})
        rescue(Exception)
          raise ConfigError.new($!, path)
        end
      end
    end
  
    include Enumerable
    include Configurable
    include Minimap
  
    # An array of nested Envs, by default comprised of the env_path
    # + gem environments (in that order).
    attr_reader :envs
  
    # A hash of cached manifests
    attr_reader :manifests
  
    # A hash of (path, Env) pairs used to prevent infinite loops of Env
    # dependencies by assigning a single Env to a given path.
    attr_reader :instances
    
    # The basename for dynamically loading configurations.  See new.
    attr_reader :basename
    
    # The Root directory structure for self.
    nest(:root, Root, :set_default => false)
  
    # Specify gems to add as nested Envs.  Gems may be specified 
    # by name and/or version, like 'gemname >= 1.2'; by default the 
    # latest version of the gem is selected.  Gems are not activated
    # by Env.
    config_attr :gems, [] do |input|
      input = YAML.load(input) if input.kind_of?(String)
      
      specs = case input
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
    
      # sort specs to ensure they appear in the natural order
      @gems = specs.uniq.sort_by do |spec|
        spec.full_name
      end
    
      reset_envs
    end

    # Specify directories to load as nested Envs.
    config_attr :env_paths, [] do |input|
      @env_paths = resolve_paths(input)
      reset_envs
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
    # Instances is used internally to prevent infinite loops of nested envs
    # and should not be modified manually.
    def initialize(config_or_dir=Dir.pwd, basename=nil, instances={})
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
        config = Env.load_config(File.join(path, basename))
      end
      
      # set instances
      @instances = instances
      if instances.has_key?(path)
        raise "instances contains an instance for: #{path}"
      end
      instances[path] = self
    
      # set these for reset_env
      @gems = nil
      @env_paths = nil
      initialize_config(config || {})
    end
    
    # The path for self (root.root).  Path is used to key self in instances.
    def path
      root.root
    end
    
    # Sets envs removing duplicates and instances of self.  Setting envs
    # overrides any environments specified by env_path and gem.
    def envs=(envs)
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
  
    # Creates a manifest with entries defined by the return of the block.  The
    # manifest will be cached in manifests if a key is provided.
    def manifest(key=nil, klass=Manifest) # :yields: env
      return manifests[key] if manifests.has_key?(key)
      
      if block_given?
        klass = Class.new(klass)
        klass.send(:define_method, :build) do
          @entries = yield(env)
        end
      end
      manifest = klass.new(self, key)
    
      # cache the manifest if a key is specified
      if key
        if manifests.has_key?(key)
          raise "a manifest already exists for: #{key} (#{inspect})"
        end
        manifests[key] = manifest
      end
    
      manifest
    end
    
    def inspect(template=nil) # :yields: templater, attrs
      return "#<#{self.class}:#{object_id} path='#{path}'>" if template == nil
      
      attrs = {}
      collect do |env|
        templater = Support::Templater.new(template, :env => env)
        block_given? ? (yield(templater, attrs) ? templater : nil) : templater
      end.compact.collect do |templater|
        templater.build(attrs)
      end.join
    end
    
    def recursive_inspect(template=nil, *args) # :yields: templater, attrs
      return "#<#{self.class}:#{object_id} path='#{path}'>" if template == nil
      
      attrs = {}
      templaters = []
      recursive_inject(args) do |argv, env|
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
    
    # Returns the minikey for an env (ie env.path).
    def entry_to_minikey(env)
      env.path
    end
    
    # Instantiates a new Env for the specified paths.
    def instantiate(path) # :nodoc:
      instances[path] || Env.new(path, basename, instances)
    end
  
    # resets envs using the current env_paths and gems.  does nothing
    # until both env_paths and gems are set.
    def reset_envs # :nodoc:
      if env_paths && gems
        self.envs = env_paths.collect do |path| 
          instantiate(path)
        end + gems.collect do |spec|
          instantiate(spec.full_gem_path)
        end
      end
    end
  
    # arrayifies, compacts, and resolves input paths using root, and
    # removes duplicates.  in short:
    #
    #   resolve_paths ['lib', nil, 'lib', 'alt]  # => [root['lib'], root['alt']]
    #
    def resolve_paths(paths) # :nodoc:
      paths = YAML.load(paths) if paths.kind_of?(String)
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
    
    # Raised when there is a configuration error from Env.load_config.
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
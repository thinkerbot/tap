require 'tap/support/constant_manifest'
require 'tap/support/gems'

module Tap
  
  # Envs are locations on the filesystem that have resources associated with
  # them (commands, tasks, generators, etc).  Envs may point to files, but it's
  # more commonly environments are set to a directory and resources are various
  # files within the directory.
  #
  #
  #--
  # Note that gems and env_paths reset envs -- custom modifications to envs will be lost
  # whenever these configs are reset.
  class Env
    include Enumerable
    include Configurable
    include Support::Minimap
    
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
      # The Env is initialized using configurations read from the env config
      # file. An instance will be initialized regardless of whether the config
      # file or directory exists.
      def instantiate(path, default_config={}, &block)
        path = config_path(path)
        config = default_config.merge(load_config(path))
        
        # note the assignment of env to instances MUST occur
        # before reconfigure to prevent infinite looping
        (instances[path] = new(:root => {:root => File.dirname(path)})).reconfigure(config, &block)
      end
      
      def instance_for(path, default_class=Env)
        path = config_path(path)
        instances.has_key?(path) ? instances[path] : default_class.instantiate(path)
      end
      
      def manifest(name, &block) # :yields: env (and should return a manifest)
        name = name.to_sym
        define_method(name) do
          self.manifests[name] ||= block.call(self).bind(self, name)
        end
      end
      
      private
      
      def config_path(path) # :nodoc:
        if File.directory?(path) || (!File.exists?(path) && File.extname(path) == "")
          path = File.join(path, DEFAULT_CONFIG_FILE) 
        end
        
        File.expand_path(path)
      end
      
      # helper to load path as YAML.  load_file returns a hash if the path
      # loads to nil or false (as happens for empty files)
      def load_config(path) # :nodoc:
        begin
          Root.trivial?(path) ? {} : (YAML.load_file(path) || {})
        rescue(Exception)
          raise Env::ConfigError.new($!, path)
        end
      end
    end
    
    @@instance = nil
    @@instances = {}

    # The default config file path
    DEFAULT_CONFIG_FILE = "tap.yml"
    
    # An array of nested Envs, by default comprised of the env_path
    # + gem environments (in that order).  Nested environments are
    # activated/deactivated with self.
    attr_reader :envs
    
    # The Root directory structure for self.
    nest(:root, Tap::Root) {|config| Tap::Root.new.reconfigure(config) }
    
    # Specify gems to load as nested Envs.  Gems may be specified 
    # by name and/or version, like 'gemname >= 1.2'; by default the 
    # latest version of the gem is selected.
    #
    # Gems are immediately loaded (via gem) through this method.
    config_attr :gems, [] do |input|
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
      @env_paths = [*input].compact.collect do |path| 
        Env.instance_for(root[path]).env_path
      end.uniq
      reset_envs
    end
    
    # Designate load paths.
    config_attr :load_paths, ["lib"] do |paths|
      raise "load_paths cannot be modified once active" if active?
      @load_paths = resolve_paths(paths)
    end
    
    # Designate paths for discovering and executing commands. 
    config_attr :command_paths, ["cmd"] do |paths|
      @command_paths = resolve_paths(paths)
    end
    
    # Designate paths for discovering generators.  
    config_attr :generator_paths, ["lib"] do |paths|
      @generator_paths = resolve_paths(paths)
    end
    
    manifest(:commands) do |env|
      paths = []
      env.command_paths.each do |path_root|
        paths.concat env.root.glob(path_root)
      end
      
      paths = paths.sort_by {|path| File.basename(path) }
      Support::Manifest.new(paths)
    end
    
    manifest(:tasks) do |env|
      tasks = Support::ConstantManifest.new('manifest')
      env.load_paths.each do |path_root|
        tasks.register(path_root, '**/*.rb')
      end
      # tasks.cache = env.cache[:tasks]
      tasks
    end

    manifest(:generators) do |env|
      generators = Support::ConstantManifest.intern('generator') do |manifest, const|
        const.name.underscore.chomp('_generator')
      end
      
      env.generator_paths.each do |path_root|
        generators.register(path_root, '**/*_generator.rb')
      end
      # generators.cache = env.cache[:generators]
      generators
    end
    
    def initialize(config={})
      @envs = []
      @active = false
      @manifests = {}

      # initialize these for reset_env
      @gems = []
      @env_paths = []
      
      initialize_config(config)
    end
    
    # Returns the key for self in Env.instances.
    def env_path
      Env.instances.each_pair {|path, env| return path if env == self }
      nil
    end
    
    # Sets envs removing duplicates and instances of self.  Setting envs
    # overrides any environments specified by env_path and gem.
    def envs=(envs)
      raise "envs cannot be modified once active" if active?
      @envs = envs.uniq.delete_if {|e| e == self }
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
      visit_envs.each {|e| yield(e) }
    end
    
    # Passes each nested env to the block in reverse order, ending with self.
    def reverse_each
      visit_envs.reverse_each {|e| yield(e) }
    end
    
    # Recursively injects the memo to each env of self.  Each env in envs
    # receives the same memo from the parent.
    #
    #   a,b,c,d,e = ('a'..'e').collect {|name| Tap::Env.new(:name => name) }
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
    # * unshift load_paths to $LOAD_PATH
    #
    # Once active, the current envs and load_paths are frozen and cannot be
    # modified until deactivated. Returns true if activate succeeded, or
    # false if self is already active.
    def activate
      return false if active?
      
      @active = true
      @@instance = self if @@instance == nil
      
      # freeze envs and load paths
      @envs.freeze
      @load_paths.freeze
      
      # activate nested envs
      envs.reverse_each do |env|
        env.activate
      end
      
      # add load paths
      load_paths.reverse_each do |path|
        $LOAD_PATH.unshift(path)
      end
      
      $LOAD_PATH.uniq!
      
      true
    end
    
    # Deactivates self by doing the following in order:
    #
    # * deactivates nested environments
    # * removes load_paths from $LOAD_PATH
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
      end
      
      # unfreeze envs and load paths
      @envs = @envs.dup
      @load_paths = @load_paths.dup
      
      # clear cached data
      @@instance = nil if @@instance == self
      @manifests.clear
      
      true
    end
    
    # Return true if self has been activated.
    def active?
      @active
    end
    
    # Searches each env for the first existing file or directory at 
    # env.root.filepath(dir, path).  Paths are expanded, and search_path
    # checks to make sure the file is, in fact, relative to env.root[dir].
    # An optional block may be used to check the file; the file will only
    # be returned if the block returns true.
    #
    # Returns nil if no file can be found.
    def search(dir, path)
      each do |env|
        directory = env.root.filepath(dir)
        file = env.root.filepath(dir, path)
        
        # check the file is relative to the
        # directory, and that the file exists.
        if file.rindex(directory, 0) == 0 && 
          File.exists?(file) && 
          (!block_given? || yield(file))
          return file
        end
      end
      
      nil
    end
    
    # 
    TEMPLATES = {}
    TEMPLATES[:commands] = %Q{<% if count > 1 %>
<%= env_name %>:
<% end %>
<% entries.each do |name, const| %>
  <%= name.ljust(width) %>
<% end %>}
    TEMPLATES[:tasks] = %Q{<% if count > 1 %>
<%= env_name %>:
<% end %>
<% entries.each do |name, const| %>
<%   desc = const.document[const.name]['manifest'] %>
  <%= name.ljust(width) %><%= desc.empty? ? '' : '  # ' %><%= desc %>
<% end %>}
    TEMPLATES[:generators] = %Q{<% if count > 1 %>
<%= env_name %>:
<% end %>
<% entries.each do |name, const| %>
<%   desc = const.document[const.name]['generator'] %>
  <%= name.ljust(width) %><%= desc.empty? ? '' : '  # ' %><%= desc %>
<% end %>}
    
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
    
    # A hash of the manifests for self.
    attr_reader :manifests
    
    def minikey(env)
      env.root.root
    end
    
    # Resets envs using the current env_paths and gems.
    def reset_envs
      self.envs = env_paths.collect do |path| 
        Env.instance_for(path)
      end + gems.collect do |spec|
        Env.instance_for(spec.full_gem_path)
      end
    end
    
    # Arrayifies, compacts, and resolves input paths using root, and
    # removes duplicates.  In short
    #
    #   resolve_paths ['lib', nil, 'lib', 'alt]  # => [root['lib'], root['alt']]
    #
    def resolve_paths(paths) # :nodoc:
      [*paths].compact.collect {|path| root[path]}.uniq
    end
    
    # Recursively iterates through envs, starting with self, and
    # collects the visited envs in order.
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
    def inject_envs(memo, visited=[], &block)  # :nodoc:
      unless visited.include?(self)
        visited << self
        next_memo = yield(memo, self)
        envs.each do |env|
          env.inject_envs(next_memo, visited, &block)
        end
      end
      
      visited
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
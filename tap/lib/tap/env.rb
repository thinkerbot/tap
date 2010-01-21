require 'tap/env/cache'
require 'tap/env/minimap'
require 'tap/env/path'

module Tap
  class Env
    autoload(:Gems, 'tap/env/gems')
    
    class << self
      def setup(dir=Dir.pwd, options={})
        env_path = options[:env_path] || ENV[ENV_PATH_VAR] || "."
        paths = Path.split(env_path, dir)
        
        gems = options[:gems] || ENV[GEMS_VAR] || default_gems
        gems = gems.split(':') if gems.kind_of?(String)
        gems.each {|gem_name| paths << Gems.gemspec(gem_name).full_gem_path }
        
        paths << HOME unless paths.include?(HOME)
        paths.collect! {|path| Path.load(path) }
        
        lib_paths = []
        paths.each {|path| lib_paths.concat(path['lib']) }
        $LOAD_PATH.replace(lib_paths + $LOAD_PATH)
        
        cache = options[:cache] || ENV[CACHE_VAR]
        constants = Cache.load(cache, lib_paths)
        
        new(:paths => paths, :constants => constants)
      end
      
      def default_gems
        Gems.select_gems do |spec|
          Path.loadable?(spec.full_gem_path)
        end
      end
    end
    
    # The home directory for Tap
    HOME = File.expand_path("#{File.dirname(__FILE__)}/../..")
    
    ENV_PATH_VAR = 'TAP_ENV_PATH'
    GEMS_VAR     = 'TAP_GEMS'
    CACHE_VAR    = 'TAP_CACHE'
    TAPRC_VAR    = 'TAPRC'
    
    attr_reader :constants
    attr_reader :paths
    
    def initialize(options={})
      @constants = [].extend Minimap
      constants = options[:constants] || []
      set(*constants)
      
      paths = options[:paths] || []
      @paths = paths.collect {|path| path.kind_of?(Path) ? path : Path.new(path) }
    end
    
    def get(key)
      if constant = constants.minimatch(key)
        constant.constantize
      else
        nil
      end
    end
    
    def set(*constants)
      constants.collect! {|constant| Constant.cast(constant) }
      @constants.concat(constants)
      @constants.uniq!
      @constants.sort!
      @keys = nil
      self
    end
    
    def keys
      @keys ||= begin
        keys = {}
        @constants.minihash.each_pair do |key, constant|
          keys[constant.const_name] = key
        end
        keys
      end
    end
    
    def key(constant)
      keys[constant.to_s]
    end
    
    def path(type)
      result = []
      paths.each do |path|
        result.concat path[type]
      end
      result
    end
  end
end
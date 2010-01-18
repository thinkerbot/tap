require 'tap/env/constant'
require 'tap/env/minimap'
require 'tap/env/path'
autoload(:YAML, 'yaml')

module Tap
  class Env
    class << self
      def setup(dir=Dir.pwd)
        Dir.chdir(dir) do
          paths = Path.split(ENV[ENV_PATH_VAR] || ".:#{HOME}")
          paths = paths.collect! {|path| load_path(path) }
          
          constants = {}
          paths.each do |path|
            load_constants(path, constants)
          end
          
          new(:paths => paths, :constants => constants.values)
        end
      end
      
      def load_path(path)
        path_file = File.join(path, PATH_FILE)
        map = Root.trivial?(path_file) ? {} : (YAML.load_file(path_file) || {})
        
        Path.new(path, map)
      end
      
      def load_constants(path, constants={})
        path['lib'].each {|lib_path| Constant.scan(lib_path, '**/*.rb', constants) }
        constants
      end
    end
    
    # The home directory for Tap
    HOME = File.expand_path("#{File.dirname(__FILE__)}/../..")
    
    ENV_PATH_VAR = 'TAP_ENV_PATH'
    GEMS_VAR     = 'TAP_GEMS'
    CACHE_VAR    = 'TAP_CACHE'
    TAPRC_VAR    = 'TAPRC'
    PATH_FILE    = 'tap.yml'
    
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
require 'tap/signals'
require 'tap/env/path'

module Tap
  class Env
    autoload(:Gems, 'tap/env/gems')
    
    include Signals
    
    attr_reader :paths
    attr_reader :constants
    attr_reader :namespaces
    
    signal :load, :class => Load, :bind => nil
    
    signal :auto, :bind => nil do |sig, argv|
      dir, pathfile, lib, pattern = argv
      lib ||= 'lib'
      pattern ||= '**/*.rb'
      path = Path.load(pathfile || 'tap.yml', dir)
      
      env = sig.obj
      env.paths << path
      path[lib].each do |lib_dir|
        env.scan(lib_dir, pattern)
      end
      env
    end
    
    signal :path, :bind => nil do |sig, argv|
      paths = sig.obj.paths
      argv.each {|path| paths << Path.parse(path) }
      paths
    end
    
    signal :set
    
    signal :ns, :bind => nil do |sig, argv|
      sig.obj.namespaces.concat(argv)
    end
    
    signal :lp, :bind => nil do |sig, argv|
      $LOAD_PATH.concat(argv)
    end
    
    signal :unpath, :bind => nil do |sig, argv|
      paths = sig.obj.paths
      paths.delete_if {|path| argv.include?(path.base) }
      paths
    end
    
    signal :unset
    
    signal :unns, :bind => nil do |sig, argv|
      namespaces = sig.obj.namespaces
      argv.each {|ns| namespaces.delete(ns) }
      namespaces
    end
    
    signal :unlp, :bind => nil do |sig, argv|
      argv.each {|path| $LOAD_PATH.delete(path) }
      $LOAD_PATH
    end
    
    def initialize(options={})
      @constants = [].extend Minimap
      constants = options[:constants] || []
      set(*constants)
      
      paths = options[:paths] || []
      @paths = paths.collect {|path| path.kind_of?(Path) ? path : Path.new(path) }
    end
    
    def scan(dir, pattern='**/*.rb')
    end
    
    def get(key)
    end
    
    def set(constant, *require_paths)
    end
    
    def unset(*constants)
    end
    
    def key(constant)
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
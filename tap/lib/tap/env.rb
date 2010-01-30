require 'tap/signals'
require 'tap/env/path'
require 'tap/env/constant'

autoload(:YAML, 'yaml')
module Tap
  class Env
    
    autoload(:Gems, 'tap/env/gems')
    include Signals
    
    attr_reader :paths
    attr_reader :constants
    attr_reader :namespaces
    
    signal_class :load, Load
    
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
    
    signal :load_path, :bind => nil do |sig, argv|
      argv.each {|path| $LOAD_PATH << File.expand_path(path) }
      $LOAD_PATH.uniq!
      $LOAD_PATH
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
    
    signal :unload_path, :bind => nil do |sig, argv|
      argv.each {|path| $LOAD_PATH.delete File.expand_path(path) }
      $LOAD_PATH
    end
    
    def initialize(options={})
      @paths = options[:paths] || []
      @paths.collect! {|path| path.kind_of?(Path) ? path : Path.new(*path) }
      
      @constants = options[:constants] || []
      @constants.collect! {|const| const.kind_of?(Constant) ? const : Constant.new(*const) }
      @constants.sort!
      
      @namespaces = options[:namespaces] || ["/"]
    end
    
    def path(type)
      result = []
      paths.each do |path|
        result.concat path[type]
      end
      result
    end
    
    def constant(const_str)
      namespaces.each do |ns|
        path = File.join(ns, const_str)
        constant = constants.find {|const| const.path == path }
        
        return constant.constantize if constant
      end
      
      constant = constants.find {|const| const.const_name == const_str }
      constant ? constant.constantize : nil
    end
    
    def set(constant, *require_paths)
      constants << Constant.new(constant, *require_paths)
      constants.sort!
    end
    
    def set?(constant)
      const_name = constant.to_s
      constants.any? {|const| const.const_name == const_name }
    end
    
    # def unset(*constants)
    # end
  end
end
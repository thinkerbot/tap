require 'tap/signals'
require 'tap/env/path'
require 'tap/env/constant'

autoload(:YAML, 'yaml')
module Tap
  class Env
    class << self
      def generate(options={})
        dir = File.expand_path(options[:dir] || Dir.pwd)
        pathfile = options[:pathfile] || File.expand_path(Path::FILE, dir)
        map = options[:map] || Path.load(pathfile)
        lib = options[:lib] || 'lib'
        pattern = options[:pattern] || '**/*.rb'
        
        lines = ["register '#{Path.escape(dir)}'"]
        path = Path.new(dir, map)
        path[lib].each do |lib_dir|
          lines << "loadpath '#{Path.escape(lib_dir)}'"
          
          Constant.scan(lib_dir, pattern).each do |const|
            lines << "set #{const.const_name} #{Path.join(const.require_paths)}"
            lines << "ns #{const.dirname}"
          end
        end
        
        lines.uniq!
        lines.sort!
        lines
      end
    end
    
    autoload(:Gems, 'tap/env/gems')
    include Signals
    
    attr_reader :paths
    attr_reader :constants
    attr_reader :namespaces
    
    signal_hash :auto,                              # auto-scan resources from a dir
      :signature => [:dir, :pathfile, :lib, :pattern]
    
    signal :register                                # add a resource path
    signal :loadpath                                # add a load path
    signal :set                                     # add a constant
    signal :ns                                      # add a namespace
    
    signal :unregister                              # remove a resource path
    signal :unloadpath                              # remove a load path
    signal :unset                                   # remove a constant
    signal :unns                                    # remove a namespace
    
    define_signal :load, Load                       # load a tapenv file
    define_signal :help, Help                       # signals help
    
    def initialize(options={})
      @paths = options[:paths] || []
      @paths.collect! {|path| path.kind_of?(Path) ? path : Path.new(*path) }
      
      @constants = {}
      constants = options[:constants] || []
      constants.each {|constant| set(*constant)}
      
      @namespaces = options[:namespaces] || ["/"]
    end
    
    def path(type)
      result = []
      paths.each do |path|
        result.concat path[type]
      end
      result
    end
    
    def resolve(const_str)
      values = constants.values
      
      namespaces.each do |ns|
        path = File.join(ns, const_str)
        constant = values.find {|constant| constant.path == path }
        return constant if constant
      end
      
      nil
    end
    
    def constant(const_str)
      case const_str
      when Module, nil
        const_str
      else
        constant = constants[const_str] || resolve(const_str)
        constant ? constant.constantize : nil
      end
    end
    
    def register(dir, map={})
      new_path = Path.new(dir, map)
      if paths.any? {|path| path == new_path }
        #raise "already registered: #{new_path}"
        return new_path
      end
      
      paths << new_path
      new_path
    end
    
    def auto(options, log=nil)
      Env.generate(options).each do |line|
        sig, *args = Utils.shellsplit(line)
        signal(sig).call(args)
      end
      self
    end
    
    def unregister(*dirs)
      dirs.collect! {|dir| File.expand_path(dir) }
      paths.delete_if {|path| dirs.include?(path.base) }
      self
    end
    
    def loadpath(*paths)
      paths.each do |path|
        path = File.expand_path(path)
        unless $LOAD_PATH.include?(path)
          $LOAD_PATH << path
        end
      end
      
      $LOAD_PATH
    end
    
    def unloadpath(*paths)
      paths.each {|path| $LOAD_PATH.delete File.expand_path(path) }
      $LOAD_PATH
    end
    
    def set(const_name, *require_paths)
      if require_paths.empty? && const_name.kind_of?(String)
        require_paths << const_name.underscore
      end
      
      constant = constants[const_name] || Constant.new(const_name)
      constant.require_paths.concat(require_paths)
      constants[constant.const_name] = constant
      constant
    end
    
    def unset(*const_names)
      const_names.each do |const_name|
        constants.delete_if do |key, constant|
          constant.const_name == const_name
        end
      end
      self
    end
    
    def ns(prefix)
      unless namespaces.include?(prefix)
        namespaces << prefix
      end
      prefix
    end
    
    def unns(*prefixes)
      prefixes.each {|prefix| namespaces.delete(prefix) }
      self
    end
  end
end
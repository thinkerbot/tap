require 'tap/signals'
require 'tap/env/cache'
require 'tap/env/constant'

autoload(:YAML, 'yaml')
module Tap
  class Env
    class << self
      def generate(options={})
        options = {
          :register => true, 
          :load_paths => true,
          :set => true
        }.merge(options)
        
        dir = File.expand_path(options[:dir] || Dir.pwd)
        pathfile = options[:pathfile] || File.expand_path(Path::FILE, dir)
        map = options[:map] || Path.load(pathfile)
        lib = options[:lib] || 'lib'
        pattern = options[:pattern] || '**/*.rb'
        
        register = options[:register]
        load_paths = options[:load_paths] 
        set = options[:set]
        
        lines = []
        lines << "register #{Path.escape(dir)}" if register
        
        path = Path.new(dir, map)
        path[lib].each do |lib_dir|
          lines << "loadpath #{Path.escape(lib_dir)}" if load_paths
          
          Constant.scan(lib_dir, pattern).each do |constant|
            require_paths = Path.join(constant.require_paths)
            types = constant.types.to_a.collect {|type| Path.escape(Path.join(type)) }
            lines << "set #{constant.const_name} #{Path.escape require_paths} #{types.join(' ')}" if set
          end
        end
        
        lines.uniq!
        lines.sort!
        lines
      end
    end
    
    include Signals
    
    attr_reader :paths
    attr_reader :constants
    
    signal_hash :auto,                              # auto-scan resources from a dir
      :signature => [:dir, :pathfile, :lib, :pattern]
    
    signal :activate, :signature => [:name, :version]
    
    signal :register                                # add a resource path
    signal :loadpath                                # add a load path
    signal :set                                     # add a constant
    
    signal :unregister                              # remove a resource path
    signal :unloadpath                              # remove a load path
    signal :unset                                   # remove a constant
    
    define_signal :load, Load                       # load a tapenv file
    define_signal :help, Help                       # signals help
    
    def initialize(options={})
      @paths = options[:paths] || []
      @paths.collect! {|path| path.kind_of?(Path) ? path : Path.new(*path) }
      @constants = options[:constants] || []
      @constants.collect! {|constant| constant.kind_of?(Constant) ? constant : Constant.new(constant) }
    end
    
    def path(type)
      result = []
      paths.each do |path|
        result.concat path[type]
      end
      result
    end
    
    def resolve(const_str, &block)
      values = const_str =~ Constant::CONST_REGEXP ? constants_by_const_name($1) : constants_by_path(const_str)
      values = values.select(&block) if block_given?
      
      case values.length
      when 0 then raise "unresolvable constant: #{const_str.inspect}"
      when 1 then values.at(0)
      else raise "multiple matching constants: #{const_str.inspect} (#{values.join(', ')})"
      end
    end
    
    def constant(const_str, &block)
      const_str.kind_of?(Module) ? const_str : resolve(const_str, &block).constantize
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
    
    def activate(name, version)
      Gem.activate(name, version)
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
    
    def set(const_name, require_path=nil, *types)
      constant = constants.find {|c| c.const_name == const_name }
      
      unless constant
        constant = Constant.new(const_name)
        constants << constant
      end
      
      require_paths = require_path ? Path.split(require_path, nil) : []
      if require_paths.empty? && const_name.kind_of?(String)
        require_paths << const_name.underscore
      end
      
      constant.require_paths.concat(require_paths).uniq!
      types.each {|type| constant.register_as(*Path.split(type, nil)) }
      
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
    
    private
    
    def constants_by_const_name(const_str) # :nodoc:
      constants.select do |constant|
        constant.const_name == const_str
      end
    end

    def constants_by_path(const_str) # :nodoc:
      head, tail = const_str.split(':', 2)
      head, tail = nil, head unless tail
      constants.select {|constant| constant.path_match?(head, tail) }
    end
  end
end
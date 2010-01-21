require 'tap/env/constant'

module Tap
  class Env
    class Cache
      class << self
        def load(cache_dir, lib_dirs)
          constants = open(cache_dir) do |cache|
            lib_dirs.collect do |lib_dir|
              cache[lib_dir] ||= scan(lib_dir)
            end
          end
          
          constants.flatten!
          constants.sort!
          constants
        end
        
        def open(cache_dir)
          cache = new(cache_dir)
          return cache unless block_given?
          
          begin
            yield(cache)
          ensure
            cache.close
          end
        end
        
        def scan(lib_dir)
          Constant.scan(lib_dir, '**/*.rb')
        end
      end
      
      INDEX = 'index'
      
      attr_reader :dir
      attr_reader :index
      attr_reader :index_file
      attr_reader :constants
      
      def initialize(dir)
        @dir = dir
        @index_file = dir ? File.expand_path(INDEX, dir) : nil
        @index = {}
        @constants = {}
        
        if index_file && File.exist?(index_file)
          File.readlines(index_file).each do |line|
            line.chomp!("\n")
            cache_path, path = line.split(' ', 2)
            index[path] = File.expand_path(cache_path, dir)
          end
        end
      end
      
      def closed?
        @dir.nil?
      end
      
      def close
        return self if closed?
        
        unless File.exists?(dir)
          FileUtils.mkdir_p(dir)
        end
        
        File.open(index_file, 'w') do |io|
          index.each_pair do |lib_dir, cache_path|
            io.puts "#{File.basename(cache_path)} #{lib_dir}"
          end
        end
        
        constants.each_pair do |lib_dir, constants|
          cache_path = index[lib_dir]
          next if File.exists?(cache_path)
          
          File.open(cache_path, 'w') do |io|
            constants.each do |constant|
              io.puts "#{constant.const_name} #{constant.require_paths.join(':')}"
            end
          end
        end
        
        @dir = nil
        self
      end
      
      def [](lib_dir)
        constants[lib_dir] ||= begin
          cache_path = index[lib_dir] ||= new_cache_path(lib_dir)
          
          if uptodate?(cache_path, lib_dir)
            File.readlines(cache_path).collect do |line|
              line.chomp!("\n")
              const_name, require_paths = line.split(' ', 2)
              Constant.new(const_name, *require_paths.split(':'))
            end
          else
            FileUtils.rm(cache_path) if File.exists?(cache_path)
            Cache.scan(lib_dir)
          end
        end
      end
      
      def []=(lib_dir, constants)
        constants[lib_dir] = constants
      end
      
      def uptodate?(cache_path, lib_dir)
        File.exists?(cache_path) &&
        FileUtils.uptodate?(cache_path, Dir.glob(File.join(lib_dir, "**/*.rb")))
      end
      
      protected
      
      def new_cache_path(lib_dir, index=0) # :nodoc:
        base = File.basename(lib_dir.chomp('/lib'))
        cache_path = File.expand_path(base, dir)
        cache_path = "#{cache_path}-#{index}" unless index == 0
        
        File.exists?(cache_path) ? new_cache_path(lib_dir, index + 1) : cache_path
      end
    end
  end
end
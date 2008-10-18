require 'tap/support/minimap'

module Tap
  module Support
    
    # Manifests store an array of paths and make them available for lookup
    # by minipath.  Manifests may be bound to a Tap::Env, allowing them
    # to search for a match across a full environment (including nested
    # environments).
    #
    # A basic Manifest has a number of hooks used by subclasses like 
    # ConstantManifest to lazily build manifest entries as needed.
    class Manifest
      class << self
        def intern(*args, &block)
          instance = new(*args)
          if block_given?
            instance.extend Support::Intern(:minikey)
            instance.minikey_block = block
          end
          instance
        end
      end
      
      include Enumerable
      include Minimap
      
      # An array entries in self.
      attr_reader :entries
      
      # The bound Tap::Env, or nil.
      attr_reader :env
      
      # The reader on Tap::Env accessing manifests
      # of the same type of entries as self.
      # reader is set during bind.
      attr_reader :reader
      
      # Initializes a new, unbound Manifest.
      def initialize(entries=[])
        @entries = entries
        @env = nil
        @reader = nil
      end
      
      # Binds self to an env and reader.  The manifests returned by env.reader
      # will be used during env-traversal methods like search.  Raises an
      # error if env does not respond to reader; returns self.
      def bind(env, reader)
        if env == nil
          raise ArgumentError, "env may not be nil" 
        end
        
        unless env.respond_to?(reader)
          raise ArgumentError, "env does not respond to #{reader}"
        end
        
        @env = env
        @reader = reader
        self
      end
      
      # Unbinds self from env.  Returns self.
      def unbind
        @env = nil
        @reader = nil
        self
      end
      
      # True if the env and reader have been set.
      def bound?
        @env != nil && @reader != nil
      end
      
      # A hook for dynamically building entries.  By default build simply
      # returns self
      def build
        self
      end
      
      # A hook to flag when self is built.  By default built? returns true.
      def built?
        true
      end
      
      # A hook to reset a build.  By default reset simply returns self.
      def reset
        self
      end
      
      # True if entries are empty.
      def empty?
        entries.empty?
      end
      
      # Iterates over each entry entry in self.
      def each
        entries.each {|entry| yield(entry) }
      end
      
      # Alias for Minimap#minimatch.
      def [](key)
        minimatch(key)
      end
      
      def search(key)
        raise "cannot search unless bound" unless bound?
        envs = env.envs(true)
        
        if key =~ /^(.*):([^:]+)$/
          env_key, key = $1, $2
          envs = [env.minimatch(env_key)].compact
        end
        
        envs.each do |env|
          if result = env.send(reader).minimatch(key)
            return result
          end
        end
        
        nil
      end
      
      def inspect(build=true)
        if build && bound?
          lines = []
          env.each do |env|
            manifest = env.send(reader).build
            next if manifest.empty?
            
            lines << "== #{env.root.root}"
            manifest.minimap.each do |mini, value| 
              lines << "  #{mini}: #{value.inspect}"
            end
          end
          return lines.join("\n")
        end
        
        lines = minimap.collect do |mini, value| 
          "  #{mini}: #{value.inspect}"
        end
        "#{self.class}:#{object_id} (#{bound? ? env.root.root : ''})\n#{lines.join("\n")}"
      end
    end
  end
end
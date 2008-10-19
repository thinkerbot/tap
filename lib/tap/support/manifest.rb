require 'tap/support/minimap'

module Tap
  module Support
    
    # Stores an array of paths and makes them available for lookup by
    # minipath.  Manifests may be bound to a Tap::Env, allowing searches
    # across a full environment (including nested environments).
    #
    # Manifest has a number of hooks used by subclasses like 
    # ConstantManifest to lazily add entries as needed.
    class Manifest
      class << self
        
        # Interns a new manifest, overriding the minikey
        # method with the block (the minikey method converts
        # entries to the path used during minimap and 
        # minimatch lookup, see Minimap).
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
      
      # Matches a compound manifest search key.  After the match,
      # if the key is compound then:
      #
      #  $1:: env_key
      #  $4:: key
      #
      # If the key is not compound, $4 is nil and $1 is the key.
      SEARCH_REGEXP = /^(([A-z]:)?.*?)(:(.*))?$/
      
      # An array entries in self.
      attr_reader :entries
      
      # The bound Tap::Env, or nil.
      attr_reader :env
      
      # The reader on Tap::Env accessing manifests of the
      # same type as self. reader is set during bind.
      attr_reader :reader
      
      # Initializes a new, unbound Manifest.
      def initialize(entries=[])
        @entries = entries
        @env = nil
        @reader = nil
      end
      
      # Binds self to an env and reader.  The manifests returned by env.reader
      # will be used during traversal methods like search.  Raises an error if
      # env does not respond to reader; returns self.
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
      
      # Search across env.each for the first entry minimatching key.
      # A single env can be specified by using a compound key like
      # 'env_key:key'.  Returns nil if no matching entry is found.
      #
      # Search raises an error unless bound?
      def search(key)
        raise "cannot search unless bound" unless bound?
        
        key =~ SEARCH_REGEXP
        envs = if $4 != nil
          # compound key, match for env
          key = $4
          [env.minimatch($1)].compact
        else
          # not a compound key, search all
          # envs by iterating env itself
          env
        end
        
        # traverse envs looking for the first
        # manifest entry matching key
        envs.each do |env|
          if result = env.send(reader).minimatch(key)
            return result
          end
        end
        
        nil
      end
      
      def inspect(traverse=true)
        if traverse && bound?
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
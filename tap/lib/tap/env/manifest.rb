require 'tap/env/minimap'

module Tap
  class Env
    
    # Stores an array of objects and makes them available for lookup by minipath.
    class Manifest
      include Enumerable
      include Minimap
    
      # Matches a compound manifest search key.  After the match, if the key is
      # compound then:
      #
      #  $1:: env_key
      #  $2:: key
      #
      # If the key is not compound, $2 is nil and $1 is the key.
      COMPOUND_REGEXP = /^((?:[A-z]:(?:\/|\\))?.*?)(?::(.*))?$/
    
      # The environment this manifest summarizes
      attr_reader :env
    
      # The key for accessing self in env.manifests
      attr_reader :key
    
      # Initializes a new Manifest.
      def initialize(env, key=nil)
        @entries = nil
        @env = env
        @key = key
      end
    
      # Determines entries for env.  By default build does nothing and must be
      # implemented in subclasses.
      def build
        @entries = []
      end
    
      # Identifies if self is built (ie entries are set).
      def built?
        @entries != nil
      end
    
      # Resets a build.
      def reset
        @entries = nil
      end
    
      # Returns the entries in self.  Builds self if necessary and allowed.
      def entries(allow_build=true)
        build if allow_build && !built?
        @entries
      end
    
      # True if entries are empty.
      def empty?
        entries.empty?
      end
    
      # Iterates over each entry in self.
      def each
        entries.each {|entry| yield(entry) }
      end
    
      # Alias for seek.
      def [](key)
        seek(key)
      end
    
      # Searches across env.each for the first entry minimatching key. A single
      # env can be specified by using a compound key like 'env_key:key'.
      #
      # Returns nil if no matching entry is found.
      def seek(key)
        key =~ COMPOUND_REGEXP
        envs = if $2
          # compound key, match for env
          key = $2
          [env.minimatch($1)].compact
        else
          # not a compound key, search all envs by iterating
          # env itself (ie treat env like an array)
          env
        end
      
        # traverse envs looking for the first
        # manifest entry matching key
        envs.each do |env|
          if result = manifest(env).minimatch(key)
            return result
          end
        end
      
        nil
      end
    
      def summarize(template)
        count = 0
        width = 10

        env_names = env.minihash(true)
        env.inspect(template) do |templater, share|
          env = templater.env
          entries = manifest(env).minimap
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
  
      def inspect(traverse=true)
        if traverse
          lines = []
          env.each do |env|
            manifest = manifest(env)
            next if manifest.empty?
          
            lines << "== #{env.path}"
            manifest.minimap.each do |mini, value| 
              lines << "  #{mini}: #{value.inspect}"
            end
          end
          return lines.join("\n")
        end
      
        lines = minimap.collect do |mini, value| 
          "  #{mini}: #{value.inspect}"
        end
        "#{self.class}:#{object_id} (#{env.path})\n#{lines.join("\n")}"
      end
    
      protected
    
      # helper method to lookup or initialize a manifest like self for env.
      def manifest(env) # :nodoc:
        env.manifest(key, self.class)
      end
    end
  end
end
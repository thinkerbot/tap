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
    
      # A hash of cached data
      attr_accessor :cache
    
      # Initializes a new Manifest.
      def initialize(env)
        @env = env
        @entries = nil
        @cache = {}
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
        @cache.clear
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
      
      # Same as env.inspect but adds manifest to the templater
      def inspect(template=nil, globals={}, filename=nil)
        return super() unless template
        
        env.inspect(template, globals, filename) do |templater, globals|
          env = templater.env
          templater.manifest = manifest(env)
          yield(templater, globals) if block_given?
        end
      end
      
      SUMMARY_TEMPLATE = %Q{#{'-' * 80}
<%= (env_key + ':').ljust(width) %> (<%= env_path %>)
<% entries.each do |key, value| %>
  <%= key.ljust(width-2) %> (<%= value %>)
<% end %>
}

      def summarize
        inspect(SUMMARY_TEMPLATE, :width => 10) do |templater, globals|
          env_key = templater.env_key
          env_path = templater.env.path
          manifest = templater.manifest
          entries = manifest.minimap
          width = globals[:width]

          # determine width
          width = env_key.length if width < env_key.length
          entries.collect! do |key, value|
            width = key.length if width < key.length
            [key, Root::Utils.relative_path(env_path, value) || value]
          end
          globals[:width] = width

          # assign locals
          templater.entries = entries
          templater.env_path = Root::Utils.relative_path(Dir.pwd, env.path) || env.path
        end
      end
            
      # Creates a new instance of self, assigned with env.
      def another(env)
        self.class.new(env)
      end
      
      protected
      
      # helper method to lookup or initialize a manifest like self for env.
      def manifest(env) # :nodoc:
        cache[env] ||= (env == self.env ? self : another(env))
      end
    end
  end
end
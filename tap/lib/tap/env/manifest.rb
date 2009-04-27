require 'tap/env/minimap'

module Tap
  class Env
    
    class Manifest
      include Enumerable
      include Minimap
      
      # The environment this manifest summarizes
      attr_reader :env
      
      # The type used to register and lookup env resources
      attr_reader :type
      
      # An optional block to discover new entries in env
      attr_reader :builder
      
      # Initializes a new Manifest.
      def initialize(env, type, &builder)
        @env = env
        @type = type
        @entries = env.registered_objects(type)
        @built = false
        @builder = builder
        @cache = {}
      end
      
      # Calls the builder to produce entries for the env.  All entries are
      # registered with env.
      def build
        return false if built?
        
        builder.call(env).each do |obj|
          env.register(type, obj)
        end if builder
        @built = true
      end
      
      def build_all
        env.each do |e|
          manifest(e).build
        end
      end
    
      # Identifies if self has been built.
      def built?
        @built
      end
      
      # Resets built? to false.
      def reset
        @built = false
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
      
      def all_empty?
        env.all? do |e|
          manifest(e).empty?
        end
      end
      
      # Iterates over each entry in self.
      def each
        entries.each {|entry| yield(entry) }
      end
      
      # Recursively iterates over the entries of each env manifest.
      def recursive_each
        env.each do |e|
          manifest(e).each do |entry|
            yield(entry)
          end
        end
      end
      
      # Registers the object in env, to type.
      def register(obj)
        env.register(type, obj)
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
        self.env.seek(type, key) do |env, k|
          manifest(env).minimatch(k)
        end
      end
      
      # Same as env.inspect but adds manifest to the templater
      def inspect(template=nil, globals={}, filename=nil)
        return super() unless template
        
        env.inspect(template, globals, filename) do |templater, globalz|
          env = templater.env
          templater.manifest = manifest(env)
          yield(templater, globalz) if block_given?
        end
      end
      
      SUMMARY_TEMPLATE = %Q{<% unless entries.empty? %>
#{'-' * 80}
<%= (env_key + ':').ljust(width) %> (<%= env_path %>)
<% entries.each do |key, value| %>
  <%= key.ljust(width-2) %> (<%= value %>)
<% end %>
<% end %>}

      def summarize
        inspect(SUMMARY_TEMPLATE, :width => 10) do |templater, globals|
          env_key = templater.env_key
          env_path = templater.env.path
          manifest = templater.manifest
          entries = manifest.minimap
          width = globals[:width]

          # determine width
          width = env_key.length if width < env_key.length
          entries.each do |key, value|
            width = key.length if width < key.length
          end
          globals[:width] = width

          # assign locals
          templater.entries = entries
          templater.env_path = env.path
        end
      end
            
      # Creates a new instance of self, assigned with env.
      def another(env)
        self.class.new(env, type, &builder)
      end
      
      protected
      
      # helper method to lookup or initialize a manifest like self for env.
      def manifest(env) # :nodoc:
        @cache[env] ||= (env == self.env ? self : another(env))
      end
    end
  end
end
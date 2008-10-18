require 'tap/support/manifestable'

module Tap
  module Support
    class Manifest
      class << self
        def normalize(key)
          key.to_s.downcase.gsub(/\s/, "_").delete(":")
        end
        
        def intern(*args, &block)
          instance = new(*args)
          if block_given?
            instance.extend Support::Intern(:minikey)
            instance.minikey_block = block
          end
          instance
        end
      end
      
      include Manifestable
      
      # An array of (key, value) entries in self.
      attr_reader :entries
      
      attr_reader :env
      
      attr_reader :type
      
      def initialize(entries=[])
        @entries = entries
        @env = nil
        @type = nil
      end
      
      def bind(env, type)
        @env = env
        @type = type
        
        unless env.respond_to?(type)
          raise ArgumentError, "env does not respond to #{type}"
        end
        self
      end
      
      def bound?
        @env != nil && @type != nil
      end
      
      def build
        self
      end
      
      def built?
        true
      end
      
      # True if entries are empty.
      def empty?
        entries.empty?
      end
      
      # Clears entries and sets the path_index to zero.
      def reset
        @entries.clear
      end
      
      # Iterates over each (key, value) entry in self, dynamically 
      # identifying entries from paths if necessary.  New 
      # entries are identifed using the each_for method.
      def each
        entries.each {|entry| yield(entry) }
      end
      
      def [](key)
        minimatch(key)
      end
      
      # Like find, but searches across all envs for the matching value.
      # An env may be specified in key to select a single
      # env to search.
      #
      def search(key)
        raise "cannot search unless bound" unless bound?
        envs = env.envs(true)
        
        if key =~ /^(.*):([^:]+)$/
          env_key, key = $1, $2
          envs = [env.minimatch(env_key)].compact
        end
        
        envs.each do |env|
          if result = env.send(type).minimatch(key)
            return result
          end
        end
        
        nil
      end
      
      def inspect(build=true)
        if build && bound?
          lines = []
          env.each do |env|
            manifest = env.send(type).build
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
      
      protected
      
      def minikey(path)
        path.gsub(/\s/, "_").delete(":")
      end
    end
  end
end
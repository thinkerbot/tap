require 'tap/env/minimap'

module Tap
  class Env
    class Manifest
      
      # Matches a compound registry search key.  After the match, if the key is
      # compound then:
      #
      #  $1:: env_key
      #  $2:: key
      #
      # If the key is not compound, $2 is nil and $1 is the key.
      COMPOUND_KEY = /^((?:[A-z]:(?:\/|\\))?.*?)(?::(.*))?$/
      
      DEFAULT_TEMPLATE = %Q{<% if !minimap.empty? && count > 1 %>
<%= env_key %>:
<% end %>
<% minimap.each do |key, entry| %>
  <%= key.ljust(width) %> # <%= entry %>
<% end %>
}

      attr_reader :env
      attr_reader :builder
      attr_reader :cache
      
      def initialize(env, builder, cache={})
        @env = env
        @builder = builder
        @cache = cache
      end
      
      def build
        self.env.each {|env| entries(env) }
        self
      end
      
      def entries(env)
        cache[env.root.root] ||= begin
          entries = builder.call(env)
          entries.kind_of?(Minimap) ? entries : entries.extend(Minimap)
        end
      end

      # Searches across each for the first registered constant minimatching key. A
      # single env can be specified by using a compound key like 'env_key:key'.
      #
      # Returns nil if no matching constant is found.
      def seek(key, value_only=true)
        key =~ COMPOUND_KEY
        envs = if $2
          # compound key, match for env
          key = $2
          [env.minimatch($1)].compact
        else
          # not a compound key, search all envs by iterating env
          env
        end

        # traverse envs looking for the first
        # manifest entry matching key
        envs.each do |env|
          if value = entries(env).minimatch(key)
            next if block_given? && !yield(value)
            return value_only ? value : [current, value]
          end
        end

        nil
      end

      def reverse_seek(key_only=true)
        self.env.each do |env|
          objects = entries(env)
          if value = objects.find {|obj| yield(obj) }
            key = objects.minihash(true)[value]
            return key_only ? key : "#{env.minihash(true)[env]}:#{key}"
          end
        end

        nil
      end
      
      def summarize(template=DEFAULT_TEMPLATE)
        env.inspect(template, :width => 11, :count => 0) do |templater, globals|
          width = globals[:width]

          minimap = entries(templater.env).minimap

          if block_given?
            minimap.collect! do |key, entry| 
              entry = yield(entry)
              entry ? [key, entry] : nil
            end
            minimap.compact! 
          end

          minimap.each do |key, entry|
            width = key.length if width < key.length
          end

          globals[:width] = width
          globals[:count] += 1 unless minimap.empty?

          templater.minimap = minimap
        end
      end
    end
  end
end
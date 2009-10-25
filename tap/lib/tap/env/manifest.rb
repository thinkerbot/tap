require 'tap/env/minimap'

module Tap
  class Env
    
    # Manifests provide concise access to resources within a nested Env.
    class Manifest
      class << self
        
        # Interns a new Manifest using the block as the builder.
        def intern(env, cache={}, &block)
          new(env, block, cache)
        end
      end
      
      include Enumerable
      
      # Matches a compound registry search key.  After the match, if the key is
      # compound then:
      #
      #  $1:: env_key
      #  $2:: key
      #
      # If the key is not compound, $2 is nil and $1 is the key.
      COMPOUND_KEY = /^((?:[A-z]:(?:\/|\\))?.*?)(?::(.*))?$/
      
      # The default summary template
      DEFAULT_TEMPLATE = %q{<% if !minimap.empty? && count > 1 %>
<%= env_key %>:
<% end %>
<% minimap.each do |key, entry| %>
  <%= key.ljust(width) %> # <%= entry %>
<% end %>
}
      
      # The Env queried for manifest data
      attr_reader :env
      
      # An object that responds to call, typically a block, that recieves
      # an env and returns an array of resources, each of which must be
      # minimappable.  Alternatively, the builder may return a Minimap.
      attr_reader :builder
      
      # A cache of (dir, [entries]) pairs mapping the root of an env
      # to the array of resources associated with the env.
      attr_reader :cache
      
      def initialize(env, builder, cache={})
        @env = env
        @builder = builder
        @cache = cache
        
        cache.each_value do |value|
          ensure_minimap(value)
        end
      end
      
      # Builds the manifest for each env in env.
      def build
        self.env.each {|env| entries(env) }
        self
      end
      
      # Returns the entries associated with env.  If no entries are currently
      # registered to env, the env is passed to the builder and the results
      # stored in the cache.
      def entries(env)
        cache[env] ||= begin
          ensure_minimap builder.call(env)
        end
      end
      
      # Yields each entry for each env to the block.
      def each
        self.env.each do |env|
          entries(env).each do |entry|
            yield(entry)
          end
        end
      end

      # Searches for the first entry mini-matching the key. A single env can 
      # be specified by using a compound key like 'env_key:key'.
      #
      # If a block is provided, each matching entry is yielded until the
      # block returns true.  Set env_also to true to return an array like
      # [env, entry], where env is the env where the entry was found.
      #
      # Returns nil if no matching entry is found.  
      def seek(key, env_also=false)
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
          if entry = entries(env).minimatch(key)
            next if block_given? && !yield(entry)
            return env_also ? [env, entry] : entry
          end
        end

        nil
      end
      
      # Unseek looks up the key identifying a specific entry.  The entry is
      # identified by the block, which receives each entry (in order) until
      # the block returns true.  Returns nil if no entry returns true.
      #
      # The env key will be prepended to the result if env_also is set to true.
      def unseek(env_also=false)
        self.env.each do |env|
          objects = entries(env)
          if value = objects.find {|entry| yield(entry) }
            key = objects.minihash(true)[value]
            return env_also ? "#{env.minihash(true)[env]}:#{key}" : key
          end
        end

        nil
      end
      
      # Generates a summary of the entries in self.  Summarize uses the inspect
      # functionality of Env to format the entries for each env in order; the
      # results are concatenated.
      #
      # The template should be ERB; it will have the following local variables:
      #
      #   env        the current env being summarized
      #   minimap    an array of [key, entry] pairs representing
      #              the minipaths and entries for the env
      #   width      the maximum width of any key across all envs
      #   count      the number of envs with at least one entry
      #
      # A block may be given to filter and pre-process minimap entries.  Each
      # (key, entry) pair will be yielded to the block; the block return
      # replaces the entry and any pairs that return nil are removed.  
      #
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
      
      private
      
      # helper to make obj into a minimap if necessary
      def ensure_minimap(obj) # :nodoc:
        obj.kind_of?(Minimap) ? obj : obj.extend(Minimap)
      end
    end
  end
end
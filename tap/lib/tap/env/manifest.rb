require 'tap/env/minimap'
require 'tap/env/constant'

module Tap
  class Env
    
    class Manifest
      include Enumerable
      include Minimap
      
      # The environment this manifest summarizes
      attr_reader :env
      
      attr_reader :type
      
      # Initializes a new Manifest.
      def initialize(env, type)
        @env = env
        @type = type
      end
      
      def entries
        env.registry[type]
      end
      
      # True if entries are empty.
      def empty?
        entries.empty?
      end
      
      def all_empty?
        env.all? do |current|
          current.manifest(type).empty?
        end
      end
      
      # Iterates over each entry in self.
      def each
        entries.each {|entry| yield(entry) }
      end
      
      # Searches across env.each for the first entry minimatching key. A single
      # env can be specified by using a compound key like 'env_key:key'.
      #
      # Returns nil if no matching entry is found.
      def seek(key)
        env.seek(type, key)
      end
      
      def [](key)
        entry = seek(key)
        entry.kind_of?(Constant) ? entry.constantize : entry
      end
      
      # Same as env.inspect but adds manifest to the templater
      def inspect(template=nil, globals={}, filename=nil)
        return super() unless template

        env.inspect(template, globals, filename) do |templater, globalz|
          env = templater.env
          templater.manifest = env.manifest(type)
          yield(templater, globalz) if block_given?
        end
      end

      SUMMARY_TEMPLATE = %Q{<% if !entries.empty? && count > 1 %>
<%= env_key %>:
<% end %>
<% entries.each do |key, entry| %>
  <%= key.ljust(width) %> # <%= entry.respond_to?(:comment) ? entry.comment : entry %>
<% end %>
}

      def summarize(template=SUMMARY_TEMPLATE)
        inspect(template, :width => 11, :count => 0) do |templater, globals|
          width = globals[:width]
          templater.entries = templater.manifest.minimap.collect! do |key, entry|
            width = key.length if width < key.length
            [key, entry]
          end

          globals[:width] = width
          globals[:count] += 1 unless templater.entries.empty?
        end
      end
      
    end
  end
end
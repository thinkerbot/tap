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
      
      def initialize(entries=[])
        @entries = entries
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
      
      def inspect
        lines = minimap.collect do |mini, value| 
          "  #{mini}: #{value.inspect}"
        end

        "#{self.class}:#{object_id}\n#{lines.join("\n")}"
      end
      
      protected
      
      def minikey(path)
        path.gsub(/\s/, "_").delete(":")
      end
    end
  end
end
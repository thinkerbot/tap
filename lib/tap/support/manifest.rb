require 'tap/root'

module Tap
  module Support
    module Manifestable
      include Enumerable
      
      def minimap
        Root.mini_map(self) {|entry| minikey(entry) }
      end

      def minimatch(key)
        find {|entry| Root.minimal_match?(minikey(entry), key) }
      end
      
      protected
      
      def minikey(entry)
        entry
      end
    end
    
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
      
      # def inspect
      #   lines = ["", "search paths:"]
      #   paths.each_with_index do |path, index|
      #     indent = (index == path_index ? "* " : "  ")
      #     lines << (indent + path.inspect)
      #   end
      #   
      #   lines << ""
      #   lines << "mini-entries:"
      #   minimize.each do |mini, value| 
      #     lines << "  #{mini}: #{value.inspect}"
      #   end
      #   lines << ""
      #   
      #   "#{self.class}:#{object_id} #{lines.join("\n")}"
      # end
      
      protected
      
      def minikey(path)
        path.gsub(/\s/, "_").delete(":")
      end
      
      def resolve(path)
        path
      end
    end
  end
end
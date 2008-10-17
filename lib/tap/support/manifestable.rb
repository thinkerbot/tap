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
  end
end
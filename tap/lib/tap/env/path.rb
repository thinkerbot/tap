module Tap
  class Env
    class Path
      class << self
        
        # Splits the path string along ':' boundaries and expands each
        # resulting fragments relative to dir.  Duplicate paths are removed. 
        # Returns the resulting paths.
        #
        # An array of pre-split paths may also be provided as an input.
        def split(str, dir=Dir.pwd)
          paths = str.kind_of?(String) ? str.split(':') : str
          paths.collect! {|path| File.expand_path(path, dir) }
          paths.uniq!
          paths
        end
      end
      
      # The path base.
      attr_reader :base
      
      # A mapping of types to paths.
      attr_reader :map
      
      # Creates a new Path relative to the base.
      def initialize(base, map={})
        @base = File.expand_path(base)
        @map = {}
        
        map.each_pair {|type, paths| self[type] = paths }
      end
      
      # Returns an array of expanded paths associated with the type; by
      # default the type expanded under base.
      def [](type)
        map[type] ||= [File.expand_path(type.to_s, base)]
      end
      
      # Sets the path for the type.  Paths are split and expanded relative to
      # base (see Path.split).
      def []=(type, paths)
        map[type] = Path.split(paths, base)
      end
      
      # Returns the base path.
      def to_s
        base
      end
    end
  end
end
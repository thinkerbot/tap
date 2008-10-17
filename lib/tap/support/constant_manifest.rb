require 'tap/support/manifest'
require 'tap/support/constant'

module Tap
  module Support

    class ConstantManifest < Support::Manifest
      
      # An array of paths to identify entries.
      attr_reader :paths
      
      # The index of the search_path that will be searched
      # next when building the manifest.
      attr_reader :path_index
      
      attr_reader :const_attr
      
      def initialize(paths, const_attr)
        @paths = paths
        @const_attr = const_attr
        @path_index = 0
        super([])
      end
      
      # Sets the paths for self.  Setting paths
      # clears all entries and puts path_index to zero.
      def paths=(paths)
        @entries = []
        @paths = paths
        @path_index = 0
      end
      
      # Clears entries and sets the path_index to zero.
      def reset
        super
        @path_index = 0
      end
      
      # Iterates over each (key, value) entry in self, dynamically 
      # identifying entries from search_paths if necessary.  New 
      # entries are identifed using the each_for method.
      def each
        entries.each do |entry|
          yield(entry)
        end
        
        # unresolved_paths = paths[path_index, paths.length - path_index]
        # count off root_path_index and path_index
        paths.each do |(path_root, paths)|
          paths.each do |path|
            new_entries = resolve(path_root, path) - entries
            entries.concat(new_entries)
            new_entries.each {|entry| yield(entry) }
          end
        end
      end
      
      protected
      
      def minikey(const)
        const.name.underscore  
      end
      
      def resolve(path_root, path)
        return [] unless File.file?(path) && document = Lazydoc.scan_doc(path, const_attr)

        relative_path = Root.relative_filepath(path_root, path).chomp(File.extname(path))
        document.default_const_name = relative_path.camelize
        document.const_names.collect {|const_name| Constant.new(const_name, path)}
      end
      
    end
  end
end
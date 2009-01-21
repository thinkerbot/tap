require 'tap/support/manifest'
require 'tap/support/constant'

module Tap
  module Support
    
    # :startdoc:::-
    #
    # ConstantManifest builds a manifest of Constant entries using Lazydoc.
    #
    # Lazydoc can quickly scan files for constant attributes, and thereby
    # identify constants based upon a flag like the '::manifest' attribute used
    # to identify task classes.  ConstantManifest registers paths that will be
    # scanned for a specific resource, and lazily builds the references to load
    # them as necessary.
    # 
    # :startdoc:::+
    class ConstantManifest < Support::Manifest
      
      # The attribute identifying constants in a file
      attr_reader :const_attr
      
      # An array of registered (root, [paths]) pairs
      # that will be searched for const_attr
      attr_reader :search_paths
      
      # The current index of search_paths
      attr_reader :search_path_index
      
      # The current index of paths
      attr_reader :path_index
      
      # Initializes a new ConstantManifest that will identify constants
      # using the specified constant attribute.
      def initialize(const_attr)
        @const_attr = const_attr
        @search_paths = []
        @search_path_index = 0
        @path_index = 0
        super([])
      end
      
      # Registers the files matching pattern under dir.  Returns self.
      def register(dir, pattern)
        paths = Dir.glob(File.join(dir, pattern)).select {|file| File.file?(file) }
        search_paths << [dir, paths.sort]
        self
      end
      
      # Searches all paths for entries and adds them to self.  Returns self.
      def build
        each {|entry| } unless built?
        self
      end
      
      # True if there are no more paths to search 
      # (ie search_path_index == search_paths.length)
      def built?
        search_path_index == search_paths.length
      end
      
      # Sets search_path_index and path_index to zero and clears entries.
      # Returns self.
      def reset
        @search_paths.each {|path| Lazydoc[path].resolved = false }
        @entries.clear
        @search_path_index = 0
        @path_index = 0
        super
      end
      
      # Yields each Constant entry to the block.  Unless built?, each
      # lazily iterates over search_paths to look for new entries.
      def each
        entries.each do |entry|
          yield(entry)
        end
        
        search_paths[search_path_index, search_paths.length - search_path_index].each do |(path_root, paths)|
          paths[path_index, paths.length - path_index].each do |path|
            new_entries = resolve(path_root, path)
            entries.concat(new_entries)
            
            @path_index += 1
            new_entries.each {|entry| yield(entry) }
          end
          
          @search_path_index += 1
          @path_index = 0
        end unless built?
      end
      
      protected
      
      def minikey(const) # :nodoc:
        const.path
      end
      
      # Scans path for constants having const_attr, and initializes Constant
      # objects for each.   If the document has no default_const_name set,
      # resolve will set the default_const_name based on the relative
      # filepath from path_root to path.
      def resolve(path_root, path) # :nodoc:
        entries = []
        document = nil
        
        Lazydoc::Document.scan(File.read(path), const_attr) do |const_name, key, value|
          if document == nil
            relative_path = Root.relative_filepath(path_root, path).chomp(File.extname(path))
            document = Lazydoc.register_file(path, relative_path.camelize)
          end
          
          const_name = document.default_const_name if const_name.empty? 
          comment = Lazydoc::Subject.new(nil, document)
          comment.value = value
          
          document[const_name][key] = comment
          entries << Constant.new(const_name, path)
        end
        
        entries
      end
      
    end
  end
end

require 'tap/support/manifest'
require 'tap/support/constant'

module Tap
  module Support
    
    # ConstantManifest builds a manifest of Constant entries using Lazydoc.  The
    # idea is that Lazydoc can find files that have resouces of a specific type
    # (ex tasks) and Constant can reference those resouces so they can be loaded
    # as necessary. ConstantManifest registers paths so that they may be lazily
    # scanned as necessary when searching for a specific resource.
    #
    #   
    #
    class ConstantManifest < Support::Manifest
      
      # The constant attribute identifying resources in a file
      attr_reader :const_attr
      
      # Registered [root, [paths]] pairs that will be searched
      # for the const_attr
      attr_reader :search_paths
      
      # The current index of search_paths
      attr_reader :search_path_index
      
      # The current index of paths
      attr_reader :path_index
      
      # Initializes a new ConstantManifest
      def initialize(const_attr)
        @const_attr = const_attr
        @search_paths = []
        @search_path_index = 0
        @path_index = 0
        super([])
      end
      
      # Registers the files matching pattern under dir.  Returns self.
      def register(dir, pattern)
        search_paths << [dir, Dir.glob(File.join(dir, pattern)).select {|file| File.file?(file) }]
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
        # Support::Lazydoc[path].resolved = false
        @entries.clear
        @search_path_index = 0
        @path_index = 0
        super
      end
      
      # Yields each entry to the block.  Unless built? is true, each lazily
      # iterates over search_paths to look for new entries.
      def each
        entries.each do |entry|
          yield(entry)
        end
        
        search_paths[search_path_index, search_paths.length - search_path_index].each do |(path_root, paths)|
          paths[path_index, paths.length - path_index].each do |path|
            new_entries = resolve(path_root, path) - entries
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
      
      def resolve(path_root, path)
        entries = []
        if document = Lazydoc.scan_doc(path, const_attr)
          if document.default_const_name.empty?
            relative_path = Root.relative_filepath(path_root, path).chomp(File.extname(path))
            document.default_const_name = relative_path.camelize
          end
          
          document.const_attrs.each_pair do |const_name, attrs|
            if attrs.has_key?(const_attr)
              entries << Constant.new(const_name, path)
            end
          end
        end
        
        entries
      end
      
    end
  end
end
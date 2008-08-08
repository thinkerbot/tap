module Tap
  module Support
    class Manifest
      
      class << self
        def initailize_from(env)
          raise NotImplementedError
        end
      end
      
      attr_reader :entries
      attr_reader :search_paths
      attr_reader :search_path_index
      
      def initialize(search_paths)
        @entries = []
        @search_paths = search_paths
        @search_path_index = 0
      end
      
      # Returns an array of the entries keys.
      def keys
        entries.collect {|(key, value)| key }
      end
      
      # Returns an array of the entries values.
      def values
        entries.collect {|(key, value)| value }
      end
      
      # True if all search paths have been checked for entries
      # (ie search_path_index == search_paths.length).
      def complete?
        @search_path_index == search_paths.length
      end
      
      # Abstract method which should yield each (key, value) pair
      # for a given search path.  Raises a NotImplementedError
      # if left not implemented.
      def each_for(search_path) # :yields: key, value
        raise NotImplementedError
      end
      
      # Adds the (key, value) pair to entries and returns the new entry.
      # Checks that entries does not already assign key a conflicting value;
      # raises an error if this is the case, or returns the existing entry.
      def store(key, value)
        existing = entries.find {|(k, v)| key == k } 
        
        if existing
          if existing[1] != value
            raise ManifestConflict.new( *conflict_argv(key, value, existing[1]) )
          else
            return existing
          end
        end
        
        new_entry = [key, value]
        entries << new_entry
        new_entry
      end
      
      # Iterates over each entry in self, dynamically identifying entries from
      # search_paths if necessary.
      #
      def each
        entries.each do |key, path| 
          yield(key, path) 
        end
        
        unless complete?
          n_to_skip = @search_path_index
          search_paths.each do |search_path|
            # advance to the current search path
            if n_to_skip > 0
              n_to_skip -= 1
              next
            end
            @search_path_index += 1
            
            # collect new entries and yield afterwards to ensure
            # that all entries for the search_path get stored
            new_entries = []
            each_for(search_path) {|key, value| new_entries << store(key, value) }
            new_entries.each {|(key, value)| yield(key, value) }
          end
        end
      end
      
      # Builds the manifest, identifying all entries from search_paths.
      # Returns self.
      def build
        each {|k, v|} unless complete?
        self
      end
      
      def minimize
        return [] if entries.empty?
        
        hash = {}
        Root.minimize(keys) do |path, mini_path|
          hash[path] = mini_path
        end
        
        entries.collect {|path, value| [hash[path], value] }
      end
      
      protected
      
      def conflict_argv(key, value, existing_value)
         [key, value, existing_value]
      end

      # Raised when multiple paths are assigned to the same manifest key.
      class ManifestConflict < StandardError
        attr_reader :key, :value, :existing
        
        def initialize(key, value, existing)
          @key = key
          @value = value
          @existing = existing
          super("attempted to store '%s': %s\nbut already was\n%s" % [key, value, existing])
        end
      end
    end
  end
end
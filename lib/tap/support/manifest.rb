require 'tap/root'

module Tap
  module Support
    class Manifest
      class << self
        def normalize(key)
          key.to_s.downcase.gsub(/\s/, "_").delete(":")
        end
      end
      
      include Enumerable
      
      # An array of (key, value) entries in self.
      attr_reader :entries
      
      # An array of search_paths to identify entries.
      attr_reader :search_paths
      
      # The index of the search_path that will be searched
      # next when building the manifest.
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
      
      # True if entries are empty.
      def empty?
        entries.empty?
      end
      
      # Clears entries and sets the search_path_index to zero.
      def reset
        @entries.clear
        @search_path_index = 0
      end
      
      # Builds the manifest, identifying all entries from search_paths.
      # Returns self.
      def build
        each {|k, v|} unless built?
        self
      end
      
      # True if all search paths have been checked for entries
      # (ie search_path_index == search_paths.length).
      def built?
        @search_path_index == search_paths.length
      end
      
      # Abstract method which should return each (key, value) entry
      # for a given search path.  Raises a NotImplementedError
      # if left not implemented.
      def entries_for(search_path)
        [[search_path, search_path]]
      end
      
      # Adds the (key, value) pair to entries and returns the new entry.
      # Checks that entries does not already assign key a conflicting value;
      # raises an error if this is the case, or returns the existing entry.
      #
      # Keys are normalized using Manifest.normalize before storing.
      def store(key, value)
        key = Manifest.normalize(key)
        existing = entries.find {|(k, v)| key == k } 
        
        if existing
          if existing[1] != value
            raise ManifestConflict.new(key, value, existing[1])
          else
            return existing
          end
        end
        
        new_entry = [key, value]
        entries << new_entry
        new_entry
      end
      
      # Iterates over each (key, value) entry in self, dynamically identifying entries 
      # from search_paths if necessary.  New entries are identifed using the each_for
      # method.
      def each
        entries.each do |key, path| 
          yield(key, path) 
        end
        
        unless built?
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
            new_entries = entries_for(*search_path)
            next if new_entries == nil
            
            new_entries.each {|(key, value)| store(key, value) }
            new_entries.each {|(key, value)| yield(key, value) }
          end
        end
      end
      
      # Returns an array of (mini_key, value) pairs, matching
      # entries by index.
      def minimize
        hash = {}
        Tap::Root.minimize(keys) do |path, mini_path|
          hash[path] = mini_path
        end
        
        entries.collect {|path, value| [hash[path], value] }
      end
      
      protected

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
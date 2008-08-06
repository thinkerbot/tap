module Tap
  module Support
    class Manifest 
      
      class << self
        def glob_method(name)
          "manifest_glob_#{name}".to_sym
        end
        
        def map_method(name)
          "manifest_map_#{name}".to_sym
        end
      end
      
      DEFAULT_MAP_METHOD = :manifest_map
 
      attr_reader :entries
      attr_reader :map_method
      attr_reader :paths
      attr_reader :path_index
      
      def initialize(name, source)
        @entries = []

        @map_method = Manifest.map_method(name)
        @map_method = DEFAULT_MAP_METHOD if !source.respond_to?(@map_method)
        
        @paths = source.send(Manifest.glob_method(name))
        @path_index = 0
      end
      
      def complete?
        @path_index == paths.length
      end
      
      def each_path
        return(false) if complete?

        n_to_skip = @path_index
        paths.each do |context, path|
          if n_to_skip > 0
            n_to_skip -= 1
            next
          end
          
          @path_index += 1
          yield(context, path)
        end
        
        true
      end
      
      # Checks that the manifest does not already assign key a conflicting path,
      # then adds the (key, path) pair to manifest.
      def store(entry)
        existing_key, existing_path = entries.find {|(key, path)| key == entry[0] } 
        
        if existing_key && existing_path != entry[1]
          raise ManifestConflict, "multiple paths for key '#{existing_key}': ['#{existing_path}', '#{entry[1]}']"
        end
      
        entries << entry
      end
      
      def mini_map
        return [] if entries.empty?
        
        keys, values = entries.sort_by {|(key, path)| File.basename(key) }.transpose
        [Root.minimize(keys), values].transpose
      end
      
      # Raised when multiple paths are assigned to the same manifest key.
      class ManifestConflict < StandardError
      end
    end
  end
end
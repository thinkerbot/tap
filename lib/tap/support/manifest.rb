require 'tap/support/manifest_spec'

module Tap
  module Support
    class Manifest
      AUTO_DISCOVER_REGEXP = /#\s*:discover:/
      
      def initialize(hash={})
        @store = {}
        hash.each_pair do |key, value|
          self[key] = value
        end
      end
      
      def auto_discover(root, load_paths)
        found = []
        load_paths.each do |load_path|
          root.glob(load_path, "**/*.rb").each do |fullpath|
            next if found.include?(fullpath)
            found << fullpath
            
            scanner = StringScanner.new(File.read(fullpath))
            next unless scanner.skip_until(AUTO_DISCOVER_REGEXP)
            
            path = root.relative_filepath(load_path, fullpath)
            name = path.chomp('.rb')
            
            class_name = scanner.scan_until(/$/).strip
            class_name = name.camelize if class_name.empty?
            
            self[name] = {:class_name => class_name, :path => path, :load_path => load_path}
          end
        end
        
        self
      end
      
      def [](key)
        store[key] ||= ManifestSpec.new(key)
      end
      
      def []=(key, value)
        store[key] = case value
        when ManifestSpec then value
        when String then ManifestSpec.new(key, :class_name => value)
        when Hash then ManifestSpec.new(key, value)
        else raise ArgumentError.new("cannot convert to ManifestSpec: #{value.class}")
        end
      end

      def to_hash
        store.dup
      end
      
      def ==(another)
        another.to_hash == store
      end
      
      protected
      
      attr_reader :store
    end 
  end
end
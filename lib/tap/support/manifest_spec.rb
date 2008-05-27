module Tap
  module Support
    class ManifestSpec
      attr_reader :name, :flags, :alias
      attr_accessor :class_name, :path, :load_path
      
      def initialize(name, attributes={})
        @name = name
        self.class_name = attributes[:class_name] || name.camelize
        self.path = attributes[:path] || name.underscore + ".rb"
        self.load_path = attributes[:load_path] || "lib"
        self.flags = attributes[:flags]
        self.alias = attributes[:alias]
      end
      
      def flags=(value)
        @flags = case value
        when Array then value
        when nil then ['run', 'server']
        else [value]
        end
      end
      
      def alias=(value)
        @alias = case value
        when Array then value
        when nil then [name]
        else [value]
        end
      end
      
      def fullpath(root)
        root.filepath(load_path, path)
      end
      
      def path_exists?(root)
        File.exists?(fullpath(root))
      end
      
      def to_hash
        { :name => name,
          :class_name => class_name,
          :alias => self.alias,
          :flags => flags,
          :path => path,
          :load_path => load_path}  
      end
      
      def tdoc
        Tap::Support::TDoc[class_name.constantize]
      end
      
      def ==(another)
        another.kind_of?(ManifestSpec) && to_hash == another.to_hash
      end
      
    end 
  end
end
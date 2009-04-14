require 'tap/env/manifest'
require 'tap/env/constant'

module Tap
  class Env
    
    #--
    # Implementation note:
    #
    # Note that the scanned constants are NOT cached in Documents.  Documents
    # track constant attributes at a global level to ensure all attributes from
    # all files are properly associated with one constant.  This works fine
    # if a constant attribute is only declared once.  In environments, and 
    # contexts where Roots get used, there are potentially several places a
    # constant attribute will be defined (ex when multiple versions declare
    # the same constant).  Hence the attribute value is not added to the
    # Lazydoc environment.
    #
    class ConstantManifest < Manifest
      
      attr_reader :const_attr
      
      def initialize(env, builder, const_attr=nil)
        super(env, builder)
        @const_attr = const_attr
      end
      
      def build
        @entries = []
        builder.call(env).each do |dir, path|
          next unless File.file?(path)
          
          unless cache.has_key?(path)
            # determine the default constant name for the path;
            # this is used when no const_name is specified for
            # a constant attribute
            default_const_name = Root::Utils.relative_path(dir, path).chomp(File.extname(path)).camelize
            
            # scan for all constant attributes
            const_names = {}
            Lazydoc::Document.scan(File.read(path), "[a-z]+") do |const_name, key, value|
              const_name = default_const_name if const_name.empty?
              
              attributes = const_names[const_name] ||= {}
              attributes[key] = value
            end
            
            # store any const_names that were found,
            # or nil if none were found
            cache[path] = const_names.empty? ? nil : const_names
          end
          
          # collect matching constants from the cache
          if const_names = cache[path]
            const_names.each_pair do |const_name, attributes|
              attributes.each_pair do |key, value|
                if const_attr == nil || const_attr === key
                  @entries << Constant.new(const_name, path, value)
                end
              end
            end
          end
        end
        
        @entries
      end
      
      protected
      
      def another(env) # :nodoc:
        ConstantManifest.new(env, builder, const_attr)
      end
      
    end
  end
end
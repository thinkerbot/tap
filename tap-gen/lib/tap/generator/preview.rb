require 'stringio'

module Tap
  module Generator
    
    # A mixin to preview the actions of a manifest, primarily used for testing.
    module Preview
      
      attr_accessor :builds
      
      def self.extended(base)
        base.instance_variable_set(:@builds, {})
      end
      
      # Returns the path of path, relative to app.root.
      def relative_path(path)
        path = app.relative_filepath(:root, path) || path
        path.empty? ? "." : path
      end
      
      # 
      def directory(target, options={})
        relative_path(target)
      end
      
      # 
      def file(target, options={})
        if block_given?
          io = StringIO.new
          yield(io)
          builds[target] = io.string
        end
        
        relative_path(target)
      end
      
    end
  end
end

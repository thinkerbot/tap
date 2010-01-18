require 'tmpdir'

module Tap
  module Test
    module FileTest
      
      # Class methods extending tests which include FileTest.
      module ClassMethods
      
        # Sets the class_root
        attr_writer :class_root
      
        # The class-level test root (a Tap::Root)
        def class_root
          @class_root ||= Root.new(Dir.tmpdir)
        end
        
        # Sets cleanup_dirs
        attr_writer :cleanup_dirs
        
        # An array of directories to be cleaned up by cleanup (default ['.'])
        def cleanup_dirs
          @cleanup_dirs ||= ['.']
        end
      end
    end
  end
end
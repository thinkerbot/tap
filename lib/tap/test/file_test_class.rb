module Tap
  module Test
    
    # Class methods extending tests which include FileTest.
    module FileTestClass
      
      # The class-level test root (a Tap::Root)
      attr_accessor :class_test_root
      
      # An array of directories to be cleaned up by cleanup
      attr_accessor :cleanup_dirs

    end
  end
end
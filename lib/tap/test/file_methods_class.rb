module Tap
  module Test
    
    # Class methods extending tests which include FileMethods.
    module FileMethodsClass
      
      # The test root structure (a Tap::Root).  All method_roots
      # are initialized as duplicates of test_root, reconfigured
      # so that root = test_root[method_name_str].
      attr_accessor :test_root
      
    end
  end
end
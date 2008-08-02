require 'tap/test/tap_methods'

module Test # :nodoc:
  module Unit # :nodoc:
    
    # Methods extending TestCase.  
    #
    # === Method Availability
    # Note that these methods are added piecemeal by Tap::Test::SubsetMethods, 
    # Tap::Test::FileMethods and Tap::Test::TapMethods, but that fact doesn't 
    # come through in the documentation.  Hence, not all of them will be available 
    # if you're only using SubsetMethods or FileMethods.  Breaks down like this:
    #
    #   Using:           Methods Available:
    #   TapMethods       all
    #   FileMethods      all, except acts_as_tap_test
    #   SubsetMethods    all, except acts_as_tap_test, acts_as_file_test, file_test_root
    #
    #--
    #See the TestTutorial for more information.
    class TestCase
    end
  end
end

module Tap
  
  # Modules facilitating testing.  TapMethods are specific to
  # Tap, but SubsetMethods and FileMethods are more general in 
  # their utility.
  module Test
  end
end





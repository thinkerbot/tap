require 'tap/root'

module Tap
  
  # Tap::Test provides several convenience methods for including and
  # setting up Tap::Test modules.  The manual use of this module looks
  # like this: 
  #
  #   class SampleTest < Test::Unit::TestCase
  #     extend Tap::Test
  #     acts_as_tap_test
  #   end
  #
  # The 'tap/test/unit' file performs this setup for Test::Unit
  # (ruby < 1.9) and Mini::Test (ruby >= 1.9); simply require it and
  # call the setup methods as necessary.
  #
  module Test
    autoload(:SubsetTest, 'tap/test/subset_test')
    autoload(:FileTest, 'tap/test/file_test')
    autoload(:ShellTest, 'tap/test/shell_test')
    autoload(:TapTest, 'tap/test/tap_test')
    autoload(:Utils, 'tap/test/utils')
    
    # Includes SubsetTest in the calling class.
    def acts_as_subset_test
      include Tap::Test::SubsetTest
    end
  
    # Includes FileTest in the calling class and instantiating class_test_root
    # (a Tap::Root).  Options may be used to configure the class_test_root.  
    #
    # Note: by default acts_as_file_test determines a root directory 
    # <em>based on the calling file</em>.  Be sure to specify the root 
    # directory manually if you call acts_as_file_test from a file that 
    # isn't the test file.
    def acts_as_file_test(options={})
      include Tap::Test::FileTest
      
      if root = options[:root]
        self.class_root = Tap::Root.new(root)
      end
      
      if cleanup_dirs = options[:cleanup_dirs]
        self.cleanup_dirs = cleanup_dirs
      end
    end
    
    # Includes ShellTest in the calling class.  Options are set as the default
    # sh_test_options.
    def acts_as_shell_test(options=nil)
      include Tap::Test::ShellTest
      self.sh_test_options.merge!(options) if options
    end
    
    # Includes TapTest in the calling class and calls acts_as_file_test with
    # the options.
    def acts_as_tap_test(options={})
      acts_as_file_test(options)
      include Tap::Test::TapTest
    end
  end
end
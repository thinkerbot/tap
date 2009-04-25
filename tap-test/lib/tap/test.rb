require 'tap/root'

module Tap
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
      
      options[:root] ||= test_root_dir
      self.class_test_root = Tap::Root.new(options)
    end
    
    # Includes ShellTest in the calling class.  Options are set as the default
    # sh_test_options.
    def acts_as_shell_test(options=nil)
      include Tap::Test::ShellTest
      self.sh_test_options = options
    end
    
    # Includes TapTest in the calling class and calls acts_as_file_test with
    # the options.
    def acts_as_tap_test(options={})
      options[:root] ||= test_root_dir
      acts_as_file_test(options)
      include Tap::Test::TapTest
    end
    
    private
  
    # Infers the test root directory from the calling file.
    #   'some_class.rb' => 'some_class'
    #   'some_class_test.rb' => 'some_class'
    def test_root_dir # :nodoc:
      # caller[1] is considered the calling file (which should be the test case)
      # note that caller entries are like this:
      #   ./path/to/file.rb:10
      #   ./path/to/file.rb:10:in 'method'
      
      calling_file = caller[1].gsub(/:\d+(:in .*)?$/, "")
      calling_file.chomp(File.extname(calling_file)).chomp("_test") 
    end
  end
end
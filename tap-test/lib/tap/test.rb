require 'tap/root'

module Tap
  module Test
    autoload(:SubsetTest, 'tap/test/subset_test')
    autoload(:FileTest, 'tap/test/file_test')
    autoload(:ShellTest, 'tap/test/shell_test')
    autoload(:Utils, 'tap/test/utils')
    autoload(:RegexpEscape, 'tap/test/regexp_escape')
    
    def acts_as_subset_test
      include Tap::Test::SubsetTest
    end
  
    # Causes a TestCase to act as a file test, by including FileTest and
    # instantiating class_test_root (a Tap::Root).  The root, relative_paths,
    # and absolute_paths used by class_test_root may be specified as options.  
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
    
    def acts_as_shell_test
      include Tap::Test::ShellTest
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
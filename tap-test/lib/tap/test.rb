require 'tap/root'

module Tap
  
  # Tap::Test provides several convenience methods for including and setting
  # up Tap::Test modules.  The manual use of this module looks like this: 
  #
  #   class SampleTest < Test::Unit::TestCase
  #     extend Tap::Test
  #     acts_as_tap_test
  #   end
  #
  # The 'tap/test/unit' file performs this setup for Test::Unit (ruby < 1.9)
  # and Mini::Test (ruby >= 1.9); simply require it and call the setup methods
  # as necessary.
  #
  #   require 'tap/test/unit'
  #   class SampleTest < Test::Unit::TestCase
  #     acts_as_tap_test
  #   end
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
  
    # Includes FileTest in the calling class and instantiates class_root.
    # Options:
    #
    #   :root:: Specifies the class_root.  String roots are used to 
    #           instantiate a new Tap::Root.
    #   :cleanup_dirs:: Specifies directories to cleanup under root.
    #
    # By default acts_as_file_test guesses a root directory using brittle
    # logic that examines caller.  Be sure to specify the root directory
    # manually if you call acts_as_file_test from a file that isn't the test
    # file, or via some proxy method.
    def acts_as_file_test(options={})
      include Tap::Test::FileTest
      
      root = options[:root] || test_root_dir
      root = Tap::Root.new(root) unless root.kind_of?(Tap::Root)
      self.class_root = root
      
      if cleanup_dirs = options[:cleanup_dirs]
        self.cleanup_dirs = cleanup_dirs
      end
    end
    
    # Includes ShellTest in the calling class.  Options are set as the default
    # sh_test_options.
    def acts_as_shell_test(options=nil)
      include Tap::Test::ShellTest
      define_method(:sh_test_options) { super.merge(options) } unless options.nil?
    end
    
    # Includes TapTest in the calling class and calls acts_as_file_test.  See
    # acts_as_file_test for valid options.
    def acts_as_tap_test(options={})
      options[:root] ||= test_root_dir
      acts_as_file_test(options)
      
      include Tap::Test::TapTest
    end
    
    private
    
    # Infers the test root directory from the calling file.
    #   'some_class_test.rb' => 'some_class_test'
    def test_root_dir # :nodoc:
      # caller[1] is considered the calling file (which should be the test case)
      # note that caller entries are like this:
      #   ./path/to/file.rb:10
      #   ./path/to/file.rb:10:in 'method'

      calling_file = caller[1].gsub(/:\d+(:in .*)?$/, "")
      calling_file.chomp(File.extname(calling_file))
    end
  end
end
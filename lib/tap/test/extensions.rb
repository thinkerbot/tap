module Tap
  
  # Modules facilitating testing.  TapTest are specific to
  # Tap, but SubsetTest and FileTest are more general in 
  # their utility.
  module Test
    autoload(:SubsetTest, 'tap/test/subset_test')
    autoload(:FileTest, 'tap/test/file_test')
    autoload(:TapTest, 'tap/test/tap_test')
    autoload(:ScriptTest, 'tap/test/script_test')
    autoload(:Utils, 'tap/test/utils')
    
    module Extensions
      def acts_as_subset_test
        include Tap::Test::SubsetTest
      end
    
      # Causes a TestCase to act as a file test, by including FileTest and
      # instantiating class_test_root (a Tap::Root).  The root and relative_paths 
      # used by class_test_root may be specified as options.  
      #
      # Note: by default acts_as_file_test determines a root directory 
      # <em>based on the calling file</em>.  Be sure to specify the root 
      # directory manually if you call acts_as_file_test from a file that 
      # isn't the test file.
      def acts_as_file_test(options={})
        include Tap::Test::FileTest
      
        options = {
          :root => test_root_dir,
          :relative_paths => {
            :input => 'input',
            :output => 'output',
            :expected => 'expected'}
        }.merge(options)
      
        self.class_test_root = Tap::Root.new(options[:root], options[:relative_paths])
      end

      # Causes a unit test to act as a tap test -- resulting in the following:
      # - setup using acts_as_file_test
      # - inclusion of Tap::Test::SubsetTest
      # - inclusion of Tap::Test::InstanceMethods 
      #
      # Note: by default acts_as_tap_test determines a root directory 
      # <em>based on the calling file</em>.  Be sure to specify the root 
      # directory manually if you call acts_as_file_test from a file that 
      # isn't the test file.
      def acts_as_tap_test(options={})
        acts_as_subset_test
        acts_as_file_test({:root => test_root_dir}.merge(options))
      
        include Tap::Test::TapTest
      end

      def acts_as_script_test(options={})
        acts_as_file_test({:root => test_root_dir}.merge(options))
      
        include Tap::Test::ScriptTest
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
end


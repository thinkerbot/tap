require 'test/unit'

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
      class << self
        
        def inherited(child)
          child.instance_variable_set(:@skip_messages, [])
          child.instance_variable_set(:@run_test_suite, true)
        end
        
        #
        # Methods for skipping a test suite
        #
        
        attr_accessor :run_test_suite

        # Causes a test suite to be skipped.  If a message is given, it will
        # print and notify the user the test suite has been skipped.
        def skip_test(msg=nil)
          self.run_test_suite = false

          # experimental -- perhaps use this so that a test can be skipped
          # for multiple reasons?
          @skip_messages << msg
        end

        alias :original_suite :suite

        # Modifies the default suite method to include/exclude tests based on platform.
        def suite # :nodoc:
          if run_test_suite
            original_suite
          else
            skip_message = @skip_messages.compact.join(', ')
            puts "Skipping #{name}#{skip_message.empty? ? '' : ': ' + skip_message}"
            Test::Unit::TestSuite.new(name)
          end
        end
        
        # Causes a TestCase to act as a file test, by instantiating a class Tap::Root 
        # (trs), and including FileMethods.  The root and directories used to 
        # instantiate trs can be specified as options.  By default file_test_root
        # and the directories {:input => 'input', :output => 'output', :expected => 'expected'} 
        # will be used.
        #
        # Note: file_test_root determines a root directory <em>based on the calling file</em>.  
        # Be sure to specify the root directory explicitly if you call acts_as_file_test
        # from a file that is NOT meant to be test file.
        def acts_as_file_test(options={})
          include Tap::Test::FileMethods
          
          options = {
            :root => file_test_root,
            :directories => {:input => 'input', :output => 'output', :expected => 'expected'}
          }.merge(options)
          self.trs = Tap::Root.new(options[:root], options[:directories])
        end

        # Causes a unit test to act as a tap test -- resulting in the following:
        # - setup using acts_as_file_test
        # - inclusion of Tap::Test::SubsetMethods
        # - inclusion of Tap::Test::InstanceMethods 
        #
        # Note:  Unless otherwise specified, <tt>acts_as_tap_test</tt> infers a root directory
        # based on the calling file. Be sure to specify the root directory explicitly 
        # if you call acts_as_file_test from a file that is NOT meant to be test file.
        def acts_as_tap_test(options={})
          include Tap::Test::SubsetMethods
          include Tap::Test::FileMethods
          include Tap::Test::TapMethods
          
          acts_as_file_test({:root => file_test_root}.merge(options))
        end

        def acts_as_script_test(options={})
          include Tap::Test::FileMethods
          include Tap::Test::ScriptMethods
          
          acts_as_file_test({:root => file_test_root}.merge(options))
        end
      end
    end
  end
end

module Tap
  
  # Modules facilitating testing.  TapMethods are specific to
  # Tap, but SubsetMethods and FileMethods are more general in 
  # their utility.
  module Test
    autoload(:SubsetMethods, 'tap/test/subset_methods')
    autoload(:FileMethods, 'tap/test/file_methods')
    autoload(:TapMethods, 'tap/test/tap_methods')
  end
end





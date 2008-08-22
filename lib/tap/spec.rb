module Tap
  module Spec

    
    # Causes a TestCase to act as a file test, by instantiating a class Tap::Root 
    # (trs), and including FileMethods.  The root and directories used to 
    # instantiate trs can be specified as options.  By default file_test_root
    # and the directories {:input => 'input', :output => 'output', :expected => 'expected'} 
    # will be used.
    #
    # Note: file_test_root determines a root directory <em>based on the calling file</em>.  
    # Be sure to specify the root directory explicitly if you call acts_as_file_test
    # from a file that is NOT meant to be test file.
    # def acts_as_file_spec(options={})
    #   include Tap::Test::FileMethods
    #   
    #   options = {
    #     :root => file_test_root,
    #     :directories => {:input => 'input', :output => 'output', :expected => 'expected'}
    #   }.merge(options)
    #   self.trs = Tap::Root.new(options[:root], options[:directories])
    # end

    # Causes a unit test to act as a tap test -- resulting in the following:
    # - setup using acts_as_file_test
    # - inclusion of Tap::Test::SubsetMethods
    # - inclusion of Tap::Test::InstanceMethods 
    #
    # Note:  Unless otherwise specified, <tt>acts_as_tap_test</tt> infers a root directory
    # based on the calling file. Be sure to specify the root directory explicitly 
    # if you call acts_as_file_test from a file that is NOT meant to be test file.
    # def acts_as_tap_spec(options={})
    #   include Tap::Test::SubsetMethods
    #   include Tap::Test::FileMethods
    #   include Tap::Test::TapMethods
    #   
    #   acts_as_file_test({:root => file_test_root}.merge(options))
    # end
    # 
    # def acts_as_script_spec(options={})
    #   include Tap::Test::FileMethods
    #   include Tap::Test::ScriptMethods
    #   
    #   acts_as_file_test({:root => file_test_root}.merge(options))
    # end
  end
end

module Tap
  
  # Modules facilitating testing.  TapMethods are specific to
  # Tap, but SubsetMethods and FileMethods are more general in 
  # their utility.
  module Test
    autoload(:SubsetMethods, 'tap/spec/subset_methods')
    autoload(:FileMethods, 'tap/spec/file_methods')
    autoload(:TapMethods, 'tap/spec/tap_methods')
  end
end





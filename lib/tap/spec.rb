module Tap
  module Spec
    
    def self.included(base)
      super
      base.send(:include, Tap::Spec::Adapter)
    end
    
    # Causes a TestCase to act as a file test, by instantiating a class Tap::Root 
    # (trs), and including FileTest.  The root and directories used to 
    # instantiate trs can be specified as options.  By default file_test_root
    # and the directories {:input => 'input', :output => 'output', :expected => 'expected'} 
    # will be used.
    #
    # Note: file_test_root determines a root directory <em>based on the calling file</em>.  
    # Be sure to specify the root directory explicitly if you call acts_as_file_test
    # from a file that is NOT meant to be test file.
    def acts_as_file_spec(options={})
      include Tap::Spec::FileTest
      
      options = {
        :root => file_test_root,
        :directories => {:input => 'input', :output => 'output', :expected => 'expected'}
      }.merge(options)
      self.trs = Tap::Root.new(options[:root], options[:directories])
    end

    # Causes a unit test to act as a tap test -- resulting in the following:
    # - setup using acts_as_file_test
    # - inclusion of Tap::Test::SubsetTest
    # - inclusion of Tap::Test::InstanceMethods 
    #
    # Note:  Unless otherwise specified, <tt>acts_as_tap_test</tt> infers a root directory
    # based on the calling file. Be sure to specify the root directory explicitly 
    # if you call acts_as_file_test from a file that is NOT meant to be test file.
    # def acts_as_tap_spec(options={})
    #   include Tap::Test::SubsetTest
    #   include Tap::Test::FileTest
    #   include Tap::Test::TapTest
    #   
    #   acts_as_file_test({:root => file_test_root}.merge(options))
    # end
    # 
    # def acts_as_script_spec(options={})
    #   include Tap::Test::FileTest
    #   include Tap::Test::ScriptTest
    #   
    #   acts_as_file_test({:root => file_test_root}.merge(options))
    # end
  end
end

module Tap
  
  # Modules facilitating testing.  TapTest are specific to
  # Tap, but SubsetTest and FileTest are more general in 
  # their utility.
  module Spec
    autoload(:SubsetTest, 'tap/spec/subset_test')
    autoload(:FileTest, 'tap/spec/file_test')
    autoload(:TapTest, 'tap/spec/tap_test')
  end
end





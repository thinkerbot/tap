require 'tap/spec/adapter'
require 'tap/test/file_test'
require 'tap/spec/file_test_class'

module Tap
  module Spec
    module FileTest
      def self.included(base)
        super
        base.send(:include, Tap::Spec::Adapter)
        base.send(:include, Tap::Test::FileTest)
        base.extend Tap::Spec::FileTestClass
      end
    end
  end
end
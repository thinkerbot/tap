require 'tap/spec/adapter'
require 'tap/test/subset_test'

module Tap
  module Spec
    module SubsetTest
      def self.included(base)
        super
        base.send(:include, Tap::Spec::Adapter)
        base.send(:include, Tap::Test::SubsetTest)
      end
    end
  end
end
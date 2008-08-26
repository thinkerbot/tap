require 'tap/spec/adapter'
require 'tap/test/subset_methods'

module Tap
  module Spec
    module SubsetMethods
      def self.included(base)
        super
        base.send(:include, Tap::Spec::Adapter)
        base.send(:include, Tap::Test::SubsetMethods)
      end
    end
  end
end
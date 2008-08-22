require 'tap/test/subset_methods'

module Tap
  module Spec
    module SubsetMethods
      def self.included(base)
        base.send(:include, Tap::Test::SubsetMethods)
      end
      
      def method_name
        self.description.gsub(" ", "_")
      end
    end
  end
end
require 'tap/spec/adapter'
require 'tap/test/file_methods'
require 'tap/spec/file_methods_class'

module Tap
  module Spec
    module FileMethods
      def self.included(base)
        base.send(:include, Tap::Spec::Adapter)
        base.send(:include, Tap::Test::FileMethods)
        base.extend Tap::Spec::FileMethodsClass
      end
    end
  end
end
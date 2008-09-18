module Tap
  module Spec
    module InheritableClassTestRoot
      def class_test_root
        @class_test_root ||= (superclass.respond_to?(:class_test_root) ? superclass.class_test_root : nil)
      end
    end
  end
end
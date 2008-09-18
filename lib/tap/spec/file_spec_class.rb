module Tap
  module Spec
    module FileTestClass
      def trs
        @trs ||= (superclass.respond_to?(:trs) ? superclass.trs : nil)
      end
      
      def file_test_root
        super.chomp("_spec") 
      end
    end
  end
end
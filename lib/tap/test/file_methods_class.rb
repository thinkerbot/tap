module Tap
  module Test
    module FileMethodsClass
      
      # Access the test root structure (a Tap::Root)
      attr_accessor :trs
      
      # Infers the test root directory from the calling file.  Ex:
      #   'some_class.rb' => 'some_class'
      #   'some_class_test.rb' => 'some_class'
      def file_test_root
        # the calling file is not the direct caller of +method_root+... this method is 
        # only accessed from within another method call, hence the target caller is caller[1] 
        # rather than caller[0].

        # caller[1] is considered the calling file (which should be the test case)
        # note that the output of calller.first is like:
        #   ./path/to/file.rb:10
        #   ./path/to/file.rb:10:in 'method'
        calling_file = caller[1].gsub(/:\d+(:in .*)?$/, "")
        calling_file.chomp!("#{File.extname(calling_file)}") 
        calling_file.chomp("_test") 
      end
    end
  end
end
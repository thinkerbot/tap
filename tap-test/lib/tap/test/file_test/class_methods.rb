module Tap
  module Test
    module FileTest
      
      # Class methods extending tests which include FileTest.
      module ClassMethods
      
        # Sets the class_root
        attr_accessor :class_root
      
        # The class-level test root (a Tap::Root)
        def class_root
          @class_root ||= Root.new(test_root_dir)
        end
        
        # Sets cleanup_dirs
        attr_writer :cleanup_dirs
        
        # An array of directories to be cleaned up by cleanup (default ['.'])
        def cleanup_dirs
          @cleanup_dirs ||= ['.']
        end
        
        private
        
        # Infers the test root directory from the calling file.
        #   'some_class.rb' => 'some_class'
        #   'some_class_test.rb' => 'some_class'
        def test_root_dir # :nodoc:
          # caller[1] is considered the calling file (which should be the test case)
          # note that caller entries are like this:
          #   ./path/to/file.rb:10
          #   ./path/to/file.rb:10:in 'method'

          calling_file = caller[1].gsub(/:\d+(:in .*)?$/, "")
          calling_file.chomp(File.extname(calling_file)).chomp("_test") 
        end
      end
    end
  end
end
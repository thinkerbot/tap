require 'tap/test/extensions'
require 'tap/spec/adapter'
require 'tap/spec/inheritable_class_test_root'

module Spec
  module Example
    class ExampleGroup
      extend Tap::Test::Extensions
      include Tap::Spec::Adapter
      
      class << self
        def acts_as_file_test(*args)
          super
          extend Tap::Spec::InheritableClassTestRoot
        end

        private

        # Infers the test root directory from the calling file.
        #   'some_class.rb' => 'some_class'
        #   'some_class_test.rb' => 'some_class'
        def test_root_dir # :nodoc:
          # caller[2] is considered the calling file (which should be the test case)
          # note that caller entries are like this:
          #   ./path/to/file.rb:10
          #   ./path/to/file.rb:10:in 'method'

          calling_file = caller[2].gsub(/:\d+(:in .*)?$/, "")
          calling_file.chomp(File.extname(calling_file)).chomp("_spec") 
        end
      end
      
      before(:each) do
        setup
      end
      
      after(:each) do
        teardown
      end
    end
  end
end
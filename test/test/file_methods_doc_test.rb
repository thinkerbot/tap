require File.join(File.dirname(__FILE__), '../tap_test_helper.rb') 
require 'tap/test/file_methods'

# documentation test
class FileMethodsDocTest < Test::Unit::TestCase
  acts_as_file_test

  def test_something
    assert_equal File.expand_path(__FILE__.chomp('_test.rb')), self.class.test_root.root
    assert_equal File.expand_path(__FILE__.chomp('_test.rb') + "/test_something"), method_root.root
    assert_equal File.expand_path(__FILE__.chomp('_test.rb') + "/test_something/input"), method_root[:input]
  end
  
  def test_sub
    assert_files do |input_files|
      input_files.collect do |filepath|
        input = File.read(filepath)
        output_file = method_root.filepath(:output, File.basename(filepath))
  
        File.open(output_file, "w") do |f|
          f << input.gsub(/input/, "output")
        end 
        
        output_file
      end
    end
  end
end

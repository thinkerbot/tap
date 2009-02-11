require "#{File.dirname(__FILE__)}/tap_test_helper.rb"

class IndependenceTest < Test::Unit::TestCase
  
  acts_as_subset_test
  
  def test_independent_files_load_without_error
    extended_test do
      load_paths = [
        File.dirname(__FILE__) + "/../lib",
        File.dirname(__FILE__) + "/../../configurable/lib",
        File.dirname(__FILE__) + "/../../lazydoc/lib"]
      
      load_paths.collect! {|path| "-I#{path}" }
    
      %w{
        tap/exe
        tap/env
        tap/root
        tap/app
        tap/support/audit
        tap/support/minimap
        tap/support/schema
        tap/support/shell_utils
        tap/support/string_ext
        tap/support/templater
        tap/support/versions
      }.each do |file|
        assert system(%Q{ruby #{load_paths.join(' ')} -e "require '#{file}'"}), file
      end
    end
  end
end
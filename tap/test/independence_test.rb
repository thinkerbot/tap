require 'test/unit'

class IndependenceTest < Test::Unit::TestCase
  
  def test_independent_files_load_without_error
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
      tap/support/combinator
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
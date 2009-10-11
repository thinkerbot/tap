require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap'

class GenerateCmdTest < Test::Unit::TestCase
  tap_root = File.expand_path(File.dirname(__FILE__) + "/../..")
  load_paths = [
    "-I'#{tap_root}/../configurable/lib'",
    "-I'#{tap_root}/../lazydoc/lib'",
    "-I'#{tap_root}/../tap/lib'",
    "-I'#{tap_root}/../tap-tasks/lib'"
  ]
  
  acts_as_file_test
  cleanup_dirs << :root
  
  acts_as_shell_test(
    :cmd_pattern => '% tap',
    :cmd => (["ruby"] + load_paths + ["'#{tap_root}/../tap/bin/tap'"]).join(" "), 
    :env => {'TAP_GEMS' => ''}
  )

  #
  # help test
  #

  def test_generate_prints_help
    sh_test "% tap generate --help" do |result|
      assert result =~ /usage: tap generate/
      assert result =~ /root\s+# /
    end
  end
  
  def test_generate_prints_help_for_no_generator_specified
    sh_test "% tap generate" do |result|
      assert result =~ /usage: tap generate/
      assert result =~ /root\s+# /
    end
  end
  
  #
  # generate/destroy test
  #
  
  def test_generate_and_destroy
    assert !File.exists?(method_root.path(:root, "sample"))
    
    sh_test "% tap generate root -d '#{method_root[:root]}' sample" do |result|
      assert result =~ /create .*\/sample/
    end
    
    assert File.exists?(method_root.path(:root, "sample"))
    
    sh_test "% tap destroy root '#{method_root.path(:root, 'sample')}'" do |result|
      assert result =~ /rm .*\/sample/
    end
    
    assert !File.exists?(method_root.path(:root, "sample"))
  end
  
  def test_generate_and_destroy_using_run_and_signals
    assert !File.exists?(method_root.path(:root, "sample"))
    
    sh_test "% tap run -- root -d '#{method_root[:root]}' sample --/0/set generate" do |result|
      assert result =~ /create .*\/sample/
    end
    
    assert File.exists?(method_root.path(:root, "sample"))
    
    sh_test "% tap run -- root '#{method_root.path(:root, 'sample')}' --/0/set destroy" do |result|
      assert result =~ /rm .*\/sample/
    end
    
    assert !File.exists?(method_root.path(:root, "sample"))
  end
end
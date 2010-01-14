require 'tap/test/unit'
class FileTestReadmeTest < Test::Unit::TestCase
  acts_as_file_test

  def test_method_root
    assert_equal "test_method_root", File.basename(method_root.path)

    path = method_root.prepare('tmp/file.txt') {|io| io << 'content' }
    assert_equal "content", File.read(path)
  end
end

require 'tap/test/unit'
class ShellTestReadmeTest < Test::Unit::TestCase
  acts_as_shell_test :cmd_pattern => '% alias', :cmd => 'echo'

  def test_echo
    assert_equal "goodnight moon", sh("echo goodnight moon").strip
  end

  def test_echo_with_an_alias
    sh_test %q{
    % alias goodnight moon
    goodnight moon
    }
  end
end

require 'tap/test/unit'
class SubsetTestReadmeTest < Test::Unit::TestCase
  acts_as_subset_test

  condition(:windows) { match_platform?('mswin') }

  def test_something_for_windows_only
    condition_test(:windows) do
      # ...
    end
  end

  def test_something_that_takes_forever
    extended_test do
      # ...
    end
  end
end

require 'tap/test/unit'
class TapTestReadmeTest < Test::Unit::TestCase
  acts_as_tap_test

  def test_node
    n = app.node { "result" }
    assert_equal "result", n.call
  end
end
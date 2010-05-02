require  File.join(File.dirname(__FILE__), '../../test_helper')
require 'tap/server/data'

class DataTest < Test::Unit::TestCase
  Data =  Tap::Server::Data
  
  acts_as_file_test
  attr_reader :p
  
  def setup
    super
    @p = Data.new(method_root)
  end
  
  #
  # entry_path test
  #
  
  def test_entry_path_returns_path_for_id
    assert_equal method_root.path(:tmp, "sub/0"), p.entry_path(:tmp, "sub/0")
  end
  
  def test_entry_path_raises_error_for_non_subpaths
    err = assert_raises(RuntimeError) { p.entry_path(:tmp, "../../file.yml") }
    assert_equal %q{not a subpath: "../../file.yml" (:tmp)}, err.message
  end
  
  #
  # entries test
  #
  
  def test_entries_returns_file_paths_under_als
    assert_equal [], p.entries(:tmp)
    
    zero = method_root.prepare(:tmp, '0') {}
    one = method_root.prepare(:tmp, '1') {}
    sub = method_root.prepare(:tmp, 'sub/0') {}
    
    assert_equal [zero, one, sub], p.entries(:tmp)
  end
  
  #
  # index test
  #
  
  def test_index_returns_a_list_of_existing_ids
    zero = method_root.prepare(:tmp, '0') {}
    one = method_root.prepare(:tmp, '1') {}
    sub = method_root.prepare(:tmp, 'sub/0') {}
    
    assert_equal ['0', '1', 'sub/0'], p.index(:tmp)
  end
  
  def test_index_returns_an_empty_array_if_no_ids_exist
    assert_equal [], p.index(:tmp)
  end
  
  #
  # create test
  #
  
  def test_create_returns_path_for_entry
    assert_equal p.entry_path(:tmp, "0"), p.create(:tmp, 0)
  end
  
  def test_create_creates_the_file_for_id
    path = p.entry_path(:tmp, "0")
    assert !File.exists?(path)
    
    p.create(:tmp, 0)
    assert File.exists?(path)
    assert_equal "", File.read(path)
  end
  
  def test_create_yields_io_to_block_if_given
    path = p.create(:tmp, 0) {|io| io << "content" }
    assert_equal "content", File.read(path)
  end
  
  def test_create_raises_error_if_file_already_exists
    path = method_root.prepare(:tmp, "0") {}
    assert File.exists?(path)
    
    e = assert_raises(RuntimeError) { p.create(:tmp, 0) }
    assert_equal "already exists: 0 (:tmp)", e.message
  end
  
  #
  # read test
  #
  
  def test_read_returns_the_contents_of_path
    path = method_root.prepare(:tmp, "0") {|io| io << "content" }
    assert_equal "content", p.read(:tmp, 0)
  end
  
  def test_read_returns_nil_if_entry_path_does_not_exist
    assert !File.exists?(p.entry_path(:tmp, "0"))
    assert_equal nil, p.read(:tmp, 0)
  end
  
  #
  # update test
  #
  
  def test_update_returns_path_for_entry
    path = method_root.prepare(:tmp, "0") {}
    assert_equal path, p.update(:tmp, 0) {}
  end
  
  def test_update_overwrites_the_content_of_the_specified_entry
    path = method_root.prepare(:tmp, "0") {|io| io << "original content" }
    p.update(:tmp, 0) {|io| io << "new content" }
    
    assert_equal "new content", File.read(path)
  end
  
  def test_update_raises_error_for_non_existant_entries
    err = assert_raises(RuntimeError) { p.update(:tmp, 0) {} }
    assert_equal "does not exist: 0 (:tmp)", err.message
  end
  
  #
  # destroy test
  #
  
  def test_destroy_removes_the_file_for_id
    path = method_root.prepare(:tmp, "0") {|io| io << "content" }
    p.destroy(:tmp, 0) 
    assert !File.exists?(path)
  end
  
  def test_destroy_returns_true_if_a_file_was_removed
    path = method_root.prepare(:tmp, "0") {|io| io << "content" }
    assert_equal true, p.destroy(:tmp, 0)
  end
  
  def test_destroy_returns_false_if_no_file_was_removed
    assert_equal false, p.destroy(:tmp, 0)
  end
end
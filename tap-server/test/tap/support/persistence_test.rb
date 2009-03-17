require  File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/support/persistence'

class PersistenceTest < Test::Unit::TestCase
  include Tap::Support
  
  acts_as_file_test
  cleanup_dirs << :data
  
  attr_reader :p
  
  def setup
    super
    @p = Persistence.new(method_root)
  end
  
  #
  # initialization test
  #
  
  def test_initialization
    p = Persistence.new(method_root)
    assert_equal method_root, p.root
  end
  
  #
  # path test
  #
  
  def test_path_returns_data_subpath_for_id
    assert_equal method_root.subpath(:data, "file.yml"), p.path("file.yml")
  end
  
  def test_path_stringifies_inputs
    assert_equal method_root.subpath(:data, "12"), p.path(12)
  end
  
  def test_path_raises_error_for_non_subpaths
    e = assert_raises(RuntimeError) { p.path("../../12") }
    assert e.message =~ /not a subpath: .*12/
  end
  
  #
  # index test
  #
  
  def test_index_returns_a_list_of_existing_ids
    p.create("a")
    p.create("b/c")
    p.create("d")
    
    assert_equal ['a', 'b/c', 'd'], p.index
  end
  
  def test_index_returns_an_empty_array_if_no_ids_exist
    assert_equal [], p.index
  end
  
  #
  # create test
  #
  
  def test_create_returns_path_for_id
    assert_equal p.path("file.yml"), p.create("file.yml")
  end
  
  def test_create_creates_the_file_for_id
    path = p.path("file.yml")
    assert !File.exists?(path)
    
    p.create("file.yml")
    assert File.exists?(path)
    assert_equal "", File.read(path)
  end
  
  def test_create_yields_io_to_block_if_given
    path = p.create("file.yml") {|io| io << "content" }
    assert_equal "content", File.read(path)
  end
  
  def test_create_raises_error_if_file_already_exists
    path = method_root.prepare(:data, "file.yml") {}
    assert File.exists?(path)
    
    e = assert_raises(RuntimeError) { p.create("file.yml") }
    assert_equal "already exists: #{path}", e.message
  end
  
  #
  # read test
  #
  
  def test_read_returns_the_contents_of_path
    path = method_root.prepare(:data, "file.yml") {|io| io << "content" }
    assert_equal "content", p.read("file.yml")
  end
  
  def test_read_returns_empty_string_if_path_does_not_exist
    assert !File.exists?(p.path("file.yml"))
    assert_equal "", p.read("file.yml")
  end
  
  #
  # update test
  #
  
  def test_update_returns_path_for_id
    path = p.update("file.yml") {}
    assert_equal p.path("file.yml"), path
  end
  
  def test_update_overwrites_the_content_of_the_specified_file
    path = method_root.prepare(:data, "file.yml") {|io| io << "original content" }
    p.update("file.yml") {|io| io << "new content" }
    
    assert_equal "new content", File.read(path)
  end
  
  def test_update_creates_non_existant_files
    path = p.update("file.yml") {|io| io << "content" }
    assert_equal "content", File.read(path)
  end
  
  #
  # destroy test
  #
  
  def test_destroy_removes_the_persistence_file_for_id
    path = method_root.prepare(:data, "file.yml") {|io| io << "content" }
    p.destroy('file.yml') 
    assert !File.exists?(path)
  end
  
  def test_destroy_returns_true_if_a_file_was_removed
    path = method_root.prepare(:data, "file.yml") {|io| io << "content" }
    assert_equal true, p.destroy('file.yml')
  end
  
  def test_destroy_returns_false_if_no_file_was_removed
    assert_equal false, p.destroy('file.yml')
  end
end
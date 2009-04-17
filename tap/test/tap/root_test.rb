require File.join(File.dirname(__FILE__), '../tap_test_helper') 
require 'tap/root'

class RootTest < Test::Unit::TestCase
  Root = Tap::Root
  
  attr_reader :r, :tr
  
  def setup
    # root
    @r = Root.new(
      :root => "./root", 
      :relative_paths => {:dir => "dir"}, 
      :absolute_paths => {:abs => '/abs/path'})
    
    # test root
    @tr = Root.new(
      :root => root_dir,
      :relative_paths => {:lib => "lib"})
  end
  
  def root_dir 
    # re-use the utils files
    File.expand_path(File.join(File.dirname(__FILE__), 'root/utils'))
  end
  
  def path_root
    path_root = File.expand_path(".")
    while (parent_dir = File.dirname(path_root)) != path_root
      path_root = parent_dir
    end
    
    path_root
  end
  
  def test_documentation
    # define a root directory with aliased relative paths
    root = Root.new(
      :root => "./root", 
      :relative_paths => {:input => 'in', :output => 'out'})
   
    # access aliased paths
    assert_equal File.expand_path("./root/in"), root[:input]
    assert_equal File.expand_path("./root/out"), root[:output]
    assert_equal File.expand_path("./root/implicit"), root['implicit']
  
    # absolute paths can also be aliased
    path = File.expand_path("/absolute/path")
    root[:abs, true] = path
    assert_equal path + "/to/file.txt", root.path(:abs, "to", "file.txt")
  
    # expanded paths are returned unchanged
    path = File.expand_path('expanded')
    assert_equal path, root[path]
  
    # work with paths
    path = root.path(:input, 'path/to/file.txt')
    assert_equal File.expand_path("./root/in/path/to/file.txt"), path
    assert_equal 'path/to/file.txt', root.relative_path(:input, path)
    assert_equal File.expand_path("./root/out/path/to/file.txt"), root.translate(path, :input, :output)
  end
  
  #
  # initialize tests
  #
  
  def test_default_root_is_expanded_dir_pwd
    r = Root.new
    
    assert_equal File.expand_path(Dir.pwd), r.root
    assert_equal({}, r.relative_paths)
  end
  
  def test_initialize_root
    r = Root.new(
      :root => "./root", 
      :relative_paths => {:dir => "dir", :temp => "tmp"}, 
      :absolute_paths => {:abs => "/abs/path"})
    
    assert_equal File.expand_path("./root"), r.root
    assert_equal({:dir => "dir", :temp => "tmp"}, r.relative_paths)
    assert_equal({:abs => File.expand_path("/abs/path")}, r.absolute_paths)
    assert_equal({
      'root' => File.expand_path("./root"), 
      :root =>  File.expand_path("./root"), 
      :dir =>   File.expand_path("./root/dir"), 
      :temp =>  File.expand_path( "./root/tmp"), 
      :abs =>   File.expand_path("/abs/path")}, 
    r.paths)
  end
  
  def test_any_object_can_be_used_as_a_directory_alias
    r = Root.new(:root => "./root", :relative_paths => {
      'dir' => "str_da",  
      :dir => 'sym_da', 
      1 => 'n_da'
    })
    
    assert_equal({
      'root' => File.expand_path("./root"), 
      :root =>  File.expand_path("./root"), 
      'dir' =>  File.expand_path("./root/str_da"), 
      :dir =>   File.expand_path("./root/sym_da"), 
      1 =>      File.expand_path("./root/n_da")}, 
    r.paths)
  end
  
  def test_path_root
    case
    when TestUtils.match_platform?("mswin")
      assert r.path_root =~ /^[A-z]:\/$/i
    when TestUtils.match_platform?("darwin")
      assert r.path_root == '/'
    else
      expected_path_root = File.expand_path(".")
      while (parent_dir = File.dirname(expected_path_root)) != expected_path_root
        expected_path_root = parent_dir
      end
      assert_equal expected_path_root, r.path_root
    end
  end
  
  def test_config_is_initialized
    r = Root.new
    assert_equal(File.expand_path(Dir.pwd), r.config[:root])
    assert_equal({}, r.config[:relative_paths])
    assert_equal({}, r.config[:absolute_paths])
  end

  #
  # set root tests
  #
  
  def test_set_root_resets_paths
    r.root = './another'
    
    assert_equal File.expand_path("./another"), r.root
    assert_equal({:dir => "dir"}, r.relative_paths)
    assert_equal({
      'root' => File.expand_path("./another"), 
      :root =>  File.expand_path("./another"), 
      :dir =>   File.expand_path("./another/dir"), 
      :abs =>   File.expand_path("/abs/path")}, 
    r.paths)
  end
  
  def root_dir_cannot_be_set_through_index
    assert_raises(ArgumentError) { r['root'] = './another' }
  end
  
  #
  # set relative_paths tests
  #
  
  def test_relative_paths_documentation
    r = Root.new
    assert_equal File.join(r.root, 'alt'), r['alt']
    r.relative_paths = {'alt' => "dir"}
    assert_equal File.join(r.root, 'dir'), r['alt']
  end
  
  def test_set_relative_paths
    r.relative_paths = {:alt => "dir"}

    assert_equal({:alt => "dir"}, r.relative_paths)
    assert_equal({
      'root' => File.expand_path("./root"), 
      :root =>  File.expand_path("./root"), 
      :alt =>   File.expand_path("./root/dir"), 
      :abs =>   File.expand_path("/abs/path")}, 
    r.paths)
  end
  
  def test_set_relative_paths_loads_string_inputs_as_yaml
    r.relative_paths = "{:alt: dir}"
    assert_equal({:alt => "dir"}, r.relative_paths)
  end
  
  def test_set_relative_paths_raises_error_if_input_is_not_a_hash
    e = assert_raises(Configurable::Validation::ValidationError) { r.relative_paths = [] }
    assert_equal "expected [Hash] but was: []", e.message
  end
  
  def test_raise_error_when_trying_to_set_root_through_relative_paths
    e = assert_raises(ArgumentError) { r.relative_paths = {'root' => "another"} }
    assert_equal "the alias \"root\" is reserved", e.message
    
    e = assert_raises(ArgumentError) { r.relative_paths = {:root => "another"} }
    assert_equal "the alias :root is reserved", e.message
  end
  
  #
  # set absolute paths test
  #
  
  def test_absolute_paths_documentation
    r = Root.new
    assert_equal File.join(r.root, 'abs'), r['abs']
    r.absolute_paths = {'abs' => File.expand_path("/path/to/dir")}
    assert_equal File.expand_path("/path/to/dir"), r['abs']
  end

  def test_set_absolute_paths
    r.absolute_paths = {:absolute => "/absolute/path"}

    assert_equal({:dir => "dir"}, r.relative_paths)
    assert_equal({
      'root' =>    File.expand_path("./root"), 
      :root =>     File.expand_path("./root"), 
      :dir =>      File.expand_path("./root/dir"), 
      :absolute => File.expand_path("/absolute/path")}, 
    r.paths)
  end
  
  def test_set_absolute_paths_loads_string_inputs_as_yaml
    r.absolute_paths = "{:absolute: /absolute/path}"
    assert_equal({:absolute => File.expand_path("/absolute/path")}, r.absolute_paths)
  end
  
  def test_set_absolute_paths_raises_error_if_input_is_not_a_hash
    e = assert_raises(Configurable::Validation::ValidationError) { r.absolute_paths = [] }
    assert_equal "expected [Hash] but was: []", e.message
  end
  
  def test_raise_error_when_trying_to_set_root_through_absolute_paths
    assert_raises(ArgumentError) { r.absolute_paths = {'root' => "another"} }
  end
  
  #
  # get absolute paths test
  #
  
  def test_absolute_paths_returns_all_non_root_paths_with_no_directory
    assert_equal({:abs => File.expand_path("/abs/path")}, r.absolute_paths)
    
    r.paths[:another] = File.expand_path("/another/path")
    assert_equal({
      :abs =>     File.expand_path("/abs/path"), 
      :another => File.expand_path("/another/path")}, 
    r.absolute_paths)
  end
  
  #
  # assignment tests
  #
  
  def test_assignment_documentation
    r = Root.new root_dir
    r[:dir] = 'path/to/dir'
    assert_equal root_dir + '/path/to/dir', r[:dir]

    r[:abs, true] = '/abs/path/to/dir'  
    assert_equal File.expand_path('/abs/path/to/dir'), r[:abs]
  end
  
  def test_set_existing_relative_path_using_assignment
    r[:dir] = 'another'
    
    assert_equal({:dir => "another"}, r.relative_paths)
    assert_equal({
      'root' => File.expand_path("./root"), 
      :root =>  File.expand_path("./root"), 
      :dir =>   File.expand_path("./root/another"), 
      :abs =>   File.expand_path("/abs/path")}, 
    r.paths)
  end
  
  def test_set_new_relative_path_using_assignment
    r[:new] = 'new'

    assert_equal({:dir => "dir", :new => "new"}, r.relative_paths)
    assert_equal({
      'root' => File.expand_path("./root"), 
      :root =>  File.expand_path("./root"), 
      :dir =>   File.expand_path("./root/dir"),
      :abs =>   File.expand_path("/abs/path"), 
      :new =>   File.expand_path("./root/new")}, 
    r.paths)
  end

  def test_absolute_paths_can_be_set_by_specifiying_absolute_true
    r[:absolute, true] = '/some/absolute/path'
    
    assert_equal({:dir => "dir"}, r.relative_paths)
    assert_equal({
      'root' => File.expand_path("./root"), 
      :root =>  File.expand_path("./root"), 
      :dir =>   File.expand_path("./root/dir"),
      :abs =>   File.expand_path("/abs/path"), 
      :absolute => File.expand_path('/some/absolute/path')},
    r.paths)
  end
  
  def test_an_absolute_path_is_not_set_if_absolute_false
    r[:not_absolute, false] = 'not/an/absolute/path'
    
    assert_equal({:dir => "dir", :not_absolute => "not/an/absolute/path"}, r.relative_paths)
    assert_equal({
      'root' => File.expand_path("./root"), 
      :root =>  File.expand_path("./root"), 
      :dir =>   File.expand_path("./root/dir"), 
      :abs =>   File.expand_path("/abs/path"), 
      :not_absolute => File.expand_path("./root/not/an/absolute/path")}, 
    r.paths)
  end
  
  def test_paths_can_be_unset_with_nil
    # Non-absolute path
    r[:dir] = '/some/path'
    assert_equal({:dir => "/some/path"}, r.relative_paths)
    assert_equal({
      'root' => File.expand_path("./root"), 
      :root =>  File.expand_path("./root"), 
      :dir =>   File.expand_path("./root/some/path"), 
      :abs =>   File.expand_path("/abs/path")}, 
    r.paths)
    
    r[:dir] = nil
    assert_equal({}, r.relative_paths)
    assert_equal({
      'root' => File.expand_path("./root"), 
      :root =>  File.expand_path("./root"), 
      :abs =>   File.expand_path("/abs/path")}, 
    r.paths)

    # the same with absolute specified
    r[:dir] = '/some/path'
    assert_equal({:dir => "/some/path"}, r.relative_paths)
    assert_equal({
      'root' => File.expand_path("./root"), 
      :root =>  File.expand_path("./root"), 
      :dir =>   File.expand_path("./root/some/path"), 
      :abs =>   File.expand_path("/abs/path")}, 
    r.paths)
    
    r[:dir, false] = nil
    assert_equal({}, r.relative_paths)
    assert_equal({
      'root' => File.expand_path("./root"), 
      :root =>  File.expand_path("./root"), 
      :abs => File.expand_path("/abs/path")}, 
    r.paths)

    # Absolute path
    r[:abs, true] = '/some/absolute/path'
    assert_equal({}, r.relative_paths)
    assert_equal({
      'root' => File.expand_path("./root"), 
      :root =>  File.expand_path("./root"), 
      :abs =>   File.expand_path('/some/absolute/path')}, 
    r.paths)
    
    r[:abs, true] = nil
    assert_equal({}, r.relative_paths)
    assert_equal({
      'root' => File.expand_path("./root"), 
      :root =>  File.expand_path("./root")}, 
    r.paths)
    
    # the same with absolute unspecfied
    r[:abs, true] = '/some/absolute/path'
    assert_equal({}, r.relative_paths)
    assert_equal({
      'root' => File.expand_path("./root"), 
      :root =>  File.expand_path("./root"), 
      :abs =>   File.expand_path('/some/absolute/path')}, 
    r.paths)
    
    r[:abs] = nil
    assert_equal({}, r.relative_paths)
    assert_equal({
      'root' => File.expand_path("./root"), 
      :root =>  File.expand_path("./root")}, 
    r.paths)
  end
  
  def test_set_path_expands_paths
    r[:dir] = "./sub/../dir"
    assert_equal File.expand_path("./root/dir"), r.paths[:dir]
    
    r[:abs, true] = "/./sub/../dir"
    assert_equal File.expand_path("/dir"), r.paths[:abs]
  end
  
  #
  # retrieve path tests
  #
  
  def test_retrieve_documentation
    r = Root.new :root => root_dir, :relative_paths => {:dir => 'path/to/dir'}
    assert_equal root_dir + '/path/to/dir', r[:dir]

    assert_equal root_dir + '/relative/path', r['relative/path']
    
    expanded_path = File.expand_path('/expanded/path')
    assert_equal expanded_path, r[expanded_path]
  end
  
  def test_retrieve_paths
    {
      :dir =>   File.expand_path("./root/dir"),
      :root =>  File.expand_path("./root"),
      'root' => File.expand_path("./root"),
      :abs => File.expand_path("/abs/path")
    }.each_pair do |dir, expected|
      assert_equal expected, r[dir]
    end
  end
  
  def test_retrieve_path_infers_path_if_path_is_not_set
    assert_equal({
      'root' => File.expand_path("./root"), 
      :root =>  File.expand_path("./root"), 
      :dir =>   File.expand_path("./root/dir"), 
      :abs => File.expand_path("/abs/path")}, 
    r.paths)
    assert_equal File.expand_path("./root/not_set"), r[:not_set]
    assert_equal File.expand_path("./root/nested/dir"), r['nested/dir']
  end
  
  def test_retrieve_path_expands_inferred_paths
    assert_equal File.expand_path("./root/nested/dir"), r['./sub/../nested/dir']
  end

  #
  # path tests
  #
  
  def test_path
    assert_equal File.expand_path("./root/dir"), r[:dir]
    assert_equal File.expand_path("./root/dir/file.txt"), r.path(:dir, "file.txt")
    assert_equal File.expand_path("./root/dir/nested/file.txt"), r.path(:dir, "nested/file.txt")
  end
  
  def test_path_when_path_is_not_set
    assert_equal File.expand_path("./root/not_set/file.txt"), r.path(:not_set, "file.txt")
    assert_equal File.expand_path("./root/folder/subfolder/file.txt"), r.path('folder/subfolder', "file.txt")
    assert_equal File.expand_path("./root/folder/subfolder/file.txt"), r.path('folder/subfolder/', "file.txt")
    assert_equal File.expand_path(path_root + "folder/subfolder/file.txt"), r.path(path_root + 'folder/subfolder', "file.txt")
  end
  
  def test_path_expands_paths
    assert_equal File.expand_path("./root/dir"), r[:dir]
    assert_equal File.expand_path("./root/dir/file.txt"), r.path(:dir, "./sub/../file.txt")
    assert_equal File.expand_path("./root/dir/nested/file.txt"), r.path(:dir, "nested/./sub/../file.txt")
  end
  
  #
  # class_path test
  #
  
  class Classpath
  end
  
  def test_class_path_returns_path_for_obj_class
    assert_equal File.expand_path("./root/dir/object"), r.class_path(:dir, Object.new)
    assert_equal File.expand_path("./root/dir/object/path"), r.class_path(:dir, Object.new, "path")
    assert_equal File.expand_path("./root/dir/root_test/classpath/path"), r.class_path(:dir, Classpath.new, "path")
  end
  
  def test_class_path_seeks_up_class_hierarchy_while_block_returns_false
    paths = []
    r.class_path(:dir, Classpath.new, "path") {|path| paths << path; false }
  
    assert_equal [
      File.expand_path("./root/dir/root_test/classpath/path"),
      File.expand_path("./root/dir/object/path")
    ], paths
  end
  
  def test_class_path_stops_seeking_when_block_returns_true
    assert_equal File.expand_path("./root/dir/object/path"), r.class_path(:dir, Object.new, "path") {|path| true }
    assert_equal File.expand_path("./root/dir/root_test/classpath/path"), r.class_path(:dir, Classpath.new, "path") {|path| true }
  end
  
  def test_class_path_returns_nil_if_block_never_returns_true
    assert_equal nil, r.class_path(:dir, Object.new, "path") {|path| false }
    assert_equal nil, r.class_path(:dir, Classpath.new, "path") {|path| false }
  end
  
  class ClassWithClasspath
    def self.class_path
      "alt"
    end
  end
  
  def test_class_path_uses_class_class_path_if_specified
    assert_equal File.expand_path("./root/dir/alt/path"), r.class_path(:dir, ClassWithClasspath.new, "path")
  end
  
  #
  # relative path tests
  #
  
  def test_relative_path
    assert_equal "file.txt", r.relative_path(:dir, "./root/dir/file.txt")
    assert_equal "nested/file.txt", r.relative_path(:dir, "./root/dir/nested/file.txt")
    assert_equal "file.txt", r.relative_path('dir/nested', "./root/dir/nested/file.txt")
    assert_equal "file.txt", r.relative_path('dir/nested/', "./root/dir/nested/file.txt")
    assert_equal "file.txt", r.relative_path(path_root + 'dir/nested', path_root + "dir/nested/file.txt")
  end

  def test_relative_path_when_path_equals_input
    assert_equal "", r.relative_path(:dir, "./root/dir")
    assert_equal "", r.relative_path(:dir, "./root/dir/")
  end
  
  def test_relative_path_expands_paths
    assert_equal "file.txt", r.relative_path(:dir, "./root/folder/.././dir/file.txt")
    assert_equal "file.txt", r.relative_path(:dir, "root/dir/file.txt")
  end
    
  def test_relative_path_when_path_is_not_set
    assert_equal "file.txt", r.relative_path(:not_set, "./root/not_set/file.txt")
    assert_equal "file.txt", r.relative_path('folder/subfolder', "./root/folder/subfolder/file.txt")
    assert_equal "file.txt", r.relative_path('folder/subfolder/', "./root/folder/subfolder/file.txt")
    assert_equal "file.txt", r.relative_path(path_root + 'folder/subfolder', path_root + "folder/subfolder/file.txt")
  end
  
  def test_relative_path_returns_nil_if_path_is_not_relative_to_aliased_dir
    assert_nil r.relative_path(:dir, "./root/file.txt")
  end
  
  def test_relative_path_returns_empty_string_if_path_is_aliased_dir
    assert_equal '', r.relative_path(:dir, r[:dir])
  end
  
  #
  # translate tests
  #
  
  def test_translate_documentation
    r = Root.new '/root_dir'
    
    path = r.path(:in, 'path/to/file.txt')
    assert_equal File.expand_path('/root_dir/in/path/to/file.txt'), path
    assert_equal File.expand_path('/root_dir/out/path/to/file.txt'), r.translate(path, :in, :out) 
  end
  
  def test_translate
    assert_equal File.expand_path("./root/another/file.txt"), r.translate("./root/dir/file.txt", :dir, :another)
    assert_equal File.expand_path("./root/another/nested/file.txt"), r.translate("./root/dir/nested/file.txt", :dir, :another)
  end
  
  def test_translate_raises_error_if_path_is_not_relative_to_aliased_input_dir
    e = assert_raises(ArgumentError) { r.translate("./root/dir/file.txt", :not_dir, :another) }
    assert_equal "\n./root/dir/file.txt\nis not relative to:\n#{r[:not_dir]}", e.message
  end
  
  #
  # glob tests
  #
  
  def test_glob_returns_all_files_matching_pattern
    assert_equal Dir.glob(File.join(root_dir, '*')),  tr.glob(:root, "*")  
    assert_equal Dir.glob(File.join(root_dir, '*.txt')),  tr.glob(:root, "*.txt")  
    assert_equal Dir.glob(File.join(root_dir, 'lib/*')),  tr.glob(:lib, "*")  
  end

  def test_default_glob_pattern_is_all_files_and_folders
    assert_equal Dir.glob(File.join(root_dir, '**/*')),  tr.glob(:root)
  end
  
  def test_glob_using_multiple_patterns            
    yml_files = Dir.glob(File.join(root_dir, '**/*.yml'))
    txt_files = Dir.glob(File.join(root_dir, '**/*.txt'))
    
    assert_equal(
      (yml_files + txt_files).sort, 
      tr.glob(:root, "**/*.yml", "**/*.txt").sort)
  end
    
  #
  # version_glob tests
  #
  
  def test_version_glob_returns_all_versions_matching_file_and_version_pattern
    assert_equal 4, Dir.glob(File.join(root_dir, 'version_glob/*')).length
    
    assert_equal 3, Dir.glob(File.join(root_dir, 'version_glob/file*.yml')).length
    assert_equal Dir.glob(File.join(root_dir, 'version_glob/file*.yml')).sort, tr.version_glob(:version_glob, 'file.yml', '*').sort
    
    assert_equal 2, Dir.glob(File.join(root_dir, 'version_glob/file-0.1*.yml')).length
    assert_equal Dir.glob(File.join(root_dir, 'version_glob/file-0.1*.yml')).sort, tr.version_glob(:version_glob, 'file.yml', "0.1*").sort
    
    assert_equal 1, Dir.glob(File.join(root_dir, 'version_glob/file-0.1.yml')).length
    assert_equal Dir.glob(File.join(root_dir, 'version_glob/file-0.1.yml')).sort, tr.version_glob(:version_glob, 'file.yml', "0.1").sort
    
    assert_equal 0, Dir.glob(File.join(root_dir, 'version_glob/file-2.yml')).length
    assert_equal [], tr.version_glob(:version_glob, 'file.yml', "2")
  end
  
  def test_default_version_glob_pattern_is_all_versions
    expected = Dir.glob(File.join(root_dir, 'version_glob/file-*.yml')) + [File.join(root_dir, 'version_glob/file.yml')]
    assert_equal expected.sort, tr.version_glob(:version_glob, 'file.yml').sort
  end
  
  def test_nil_version_glob_pattern_matches_the_no_version_file
    assert_equal [File.join(root_dir, 'version_glob/file.yml')], tr.version_glob(:version_glob, 'file.yml', nil)
    assert_equal [File.join(root_dir, 'version_glob/file.yml')], tr.version_glob(:version_glob, 'file.yml', '')
  end
  
  def test_version_glob_using_multiple_verson_patterns            
    expected = [
      File.join(root_dir, 'version_glob/file-0.1.2.yml'),
      File.join(root_dir, 'version_glob/file-0.1.yml')]
    
    assert_equal expected.sort, tr.version_glob(:version_glob, "file.yml", "0.1.2", "0.1").sort
  end
  
  def test_version_glob_filters_for_unique_files      
    expected = [File.join(root_dir, 'version_glob/file-0.1.2.yml')]
    
    assert_equal expected, tr.version_glob(:version_glob, "file.yml", "0.1.2", "0.1.*")
  end
  
  #
  # prepare test
  #
  
  def test_prepares_makes_a_path_from_the_inputs_and_prepares_it
    path = root_dir + '/non/existant/path'
    assert !File.exists?(root_dir + '/non')
    begin
      assert_equal path, tr.prepare('non', 'existant', 'path') {|file| file << "content"}
      assert File.exists?(path)
      assert_equal "content", File.read(path)
    ensure
      FileUtils.rm_r(root_dir + '/non') if File.exists?(root_dir + '/non')
    end
  end
end
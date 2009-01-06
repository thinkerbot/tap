require File.join(File.dirname(__FILE__), '../../tap_test_helper.rb')
require 'tap/generator/preview'

class PreviewTest < Test::Unit::TestCase
  include Tap::Generator
  include Preview
  
  attr_reader :app
  
  def setup
    @app = Tap::App.instance = Tap::App.new
    @builds = {}
  end
  
  #
  # documentation test
  #
  
  class Sample < Tap::Generator::Base
    def manifest(m)
      dir = app.filepath(:root, 'dir')

      m.directory dir
      m.file(File.join(dir, 'file.txt')) {|io| io << "content"}
    end
  end
  
  def test_documentation
    s = Sample.new.extend Preview
    assert_equal %w{
      dir
      dir/file.txt
    }, s.process
  
    builds = s.builds
    assert_equal "content", builds['dir/file.txt']
  end
  
  #
  # extended test
  #
  
  def test_preview_extend_initializes_builds
    s = Sample.new
    assert !s.respond_to?(:builds)
    
    s.extend Preview
    assert_equal({}, s.builds)
  end

  #
  # relative_path test
  #
  
  def test_relative_path_returns_the_path_of_path_relative_to_root
    path = app.filepath("path/to/file.txt")
    assert_equal "path/to/file.txt", relative_path(path)
  end
  
  def test_relative_path_returns_dot_for_app_root
    assert_equal ".", relative_path(app.root)
  end
  
  def test_relative_path_returns_full_path_for_paths_not_relative_to_root
    path = File.expand_path("/path/to/dir")
    assert_equal nil, Tap::Root.relative_filepath(app.root, path)
    assert_equal path, relative_path(path)
  end

  #
  # directory test
  #
  
  def test_directory_returns_the_relative_path_of_the_target
    path = app.filepath("path/to/file.txt")
    assert_equal "path/to/file.txt", directory(path)
  end

  #
  # file test
  #
  
  def test_file_returns_the_relative_path_of_the_target
    path = app.filepath("path/to/file.txt")
    assert_equal "path/to/file.txt", file(path)
  end
  
  def test_file_stores_block_content_in_builds
    path = app.filepath("file.txt")
    assert_equal({}, builds)
    file(path) {|io| io << "content"}
    assert_equal({'file.txt' => 'content'}, builds)
  end
end
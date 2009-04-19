require File.join(File.dirname(__FILE__), '../../tap_test_helper.rb')
require 'tap/generator/base'
require 'tap/generator/preview'

class PreviewTest < Test::Unit::TestCase
  include Tap::Generator
  include Preview
  
  attr_accessor :destination_root
  
  def setup
    @destination_root = Dir.pwd
    @preview = {}
  end
  
  #
  # documentation test
  #
  
  class Sample < Tap::Generator::Base
    def manifest(m)
      dir = path('dir')

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
  
    assert_equal "content", s.preview['dir/file.txt']
  end
  
  #
  # extended test
  #
  
  def test_preview_extend_initializes_preview
    s = Sample.new
    assert !s.respond_to?(:preview)
    
    s.extend Preview
    assert_equal({}, s.preview)
  end

  #
  # relative_path test
  #
  
  def test_relative_path_returns_the_path_of_path_relative_to_destination_root
    path = File.expand_path("path/to/file.txt", destination_root)
    assert_equal "path/to/file.txt", relative_path(path)
  end
  
  def test_relative_path_returns_dot_for_destination_root
    assert_equal ".", relative_path(destination_root)
  end
  
  def test_relative_path_returns_full_path_for_paths_not_relative_to_destination_root
    path = File.expand_path("/path/to/dir")
    @destination_root = File.expand_path("/path/to/destination_root")
    
    assert_equal nil, Tap::Root::Utils.relative_path(destination_root, path)
    assert_equal path, relative_path(path)
  end

  #
  # directory test
  #
  
  def test_directory_returns_the_relative_path_of_the_target
    path = File.expand_path("path/to/file.txt", destination_root)
    assert_equal "path/to/file.txt", directory(path)
  end

  #
  # file test
  #
  
  def test_file_returns_the_relative_path_of_the_target
    path = File.expand_path("path/to/file.txt", destination_root)
    assert_equal "path/to/file.txt", file(path)
  end
  
  def test_file_stores_block_content_in_preview
    path = File.expand_path("file.txt", destination_root)
    assert_equal({}, preview)
    file(path) {|io| io << "content"}
    assert_equal({'file.txt' => 'content'}, preview)
  end
end
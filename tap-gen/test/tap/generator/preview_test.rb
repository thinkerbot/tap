require File.join(File.dirname(__FILE__), '../../tap_test_helper.rb')
require 'tap/generator/preview'
require 'stringio'

class PreviewTest < Test::Unit::TestCase
  include Tap::Generator::Preview
  
  acts_as_tap_test
  
  # this establishes the essential interface provided by Base
  attr_accessor :log, :pretend
  
  def setup
    super
    @pretend = false
    @log = []
    @preview = []
    @builds = {}
  end

  #
  # relative_path test
  #
  
  def test_relative_path_returns_the_path_of_path_relative_to_root
    path = app.filepath("path/to/file.txt")
    assert_equal "path/to/file.txt", relative_path(path)
  end

end
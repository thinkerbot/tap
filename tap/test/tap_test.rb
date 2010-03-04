require File.expand_path('../tap_test_helper', __FILE__)
require 'tap'
require 'tap/test'

class TapTest < Test::Unit::TestCase
  extend Tap::Test
  acts_as_file_test
  
  #
  # setup test
  #
  
  def test_setup_scans_env_dir_path_for_constants
    method_root.prepare('one/lib/a.rb')   {|io| io.puts '# ::task'}
    method_root.prepare('one/lib/b/c.rb') {|io| io.puts '# B::task'}
    method_root.prepare('two/lib/c.rb')   {|io| io.puts '# ::task'}
    
    app = Tap.setup(:env_dir_path => "#{method_root.path('one')}:#{method_root.path('two')}")
    
    a = app.env.constants['A']
    assert_equal ['a.rb'], a.require_paths
    
    b = app.env.constants['B']
    assert_equal ['b/c.rb'], b.require_paths
    
    c = app.env.constants['C']
    assert_equal ['c.rb'], c.require_paths
  end
  
  def test_setup_loads_taprc_path_in_app_context
    a = method_root.prepare('a') do |io|
      io.puts "set 0 load"
      io.puts "set 1 load"
    end
    
    b = method_root.prepare('b') do |io|
      io.puts "set 1 dump"
    end
    
    app = Tap.setup(:taprc_path => "#{a}:#{b}")
    assert_equal Tap::Tasks::Load, app.get('0').class
    assert_equal Tap::Tasks::Dump, app.get('1').class
  end
end
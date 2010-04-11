require File.expand_path('../tap_test_helper', __FILE__)
require 'tap'
require 'tap/test/unit'

class TapTest < Test::Unit::TestCase
  extend Tap::Test
  acts_as_file_test
  
  #
  # setup test
  #
  
  def test_setup_loads_files_on_tapfile_path
    a = method_root.prepare('a')   {|io| io.puts 'Tap::App.current.set("A", Tap::App.current)'}
    b = method_root.prepare('b')   {|io| io.puts 'Tap::App.current.set("B", Tap::App.current)'}
    app = Tap.setup(:tapfile => "#{a}:#{b}")
    
    assert_equal app, app.objects['A']
    assert_equal app, app.objects['B']
  end
  
  def test_setup_scans_path_for_constants
    method_root.prepare('one/lib/a.rb')   {|io| io.puts '# ::task'}
    method_root.prepare('one/lib/b/c.rb') {|io| io.puts '# B::task'}
    method_root.prepare('two/lib/c.rb')   {|io| io.puts '# ::task'}
    
    app = Tap.setup(:path => "#{method_root.path('one')}:#{method_root.path('two')}")
    
    assert_equal ['a.rb'], app.env.resolve('A').require_paths
    assert_equal ['b/c.rb'], app.env.resolve('B').require_paths
    assert_equal ['c.rb'], app.env.resolve('C').require_paths
  end
  
  def test_setup_loads_files_on_tapenv_path_in_env_context
    method_root.prepare('one/lib/a.rb')   {|io| io.puts '# ::task'}
    method_root.prepare('two/lib/b/c.rb') {|io| io.puts '# B::task'}
    
    a = method_root.prepare('a') {|io| io.puts "auto '#{method_root.path('one')}'" }
    b = method_root.prepare('b') {|io| io.puts "auto '#{method_root.path('two')}'" }
    
    app = Tap.setup(:tapenv => "#{a}:#{b}")
    
    assert_equal ['a.rb'], app.env.resolve('A').require_paths
    assert_equal ['b/c.rb'], app.env.resolve('B').require_paths
  end
  
  def test_setup_loads_files_on_taprc_path_in_app_context
    a = method_root.prepare('a') do |io|
      io.puts "env/set Tap::Tasks::Load"
      io.puts "set 0 tap/tasks/load"
      io.puts "set 1 tap/tasks/load"
    end
    
    b = method_root.prepare('b') do |io|
      io.puts "env/set Tap::Tasks::Dump"
      io.puts "set 1 tap/tasks/dump"
    end
    
    app = Tap.setup(:taprc => "#{a}:#{b}")
    assert_equal Tap::Tasks::Load, app.get('0').class
    assert_equal Tap::Tasks::Dump, app.get('1').class
  end
end
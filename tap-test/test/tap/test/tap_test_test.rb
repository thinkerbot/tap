require  File.dirname(__FILE__) + '/../tap_test_helper'
require 'tap/test'

class TestSetupTest < Test::Unit::TestCase
  acts_as_tap_test(
    :root => "alt/root", 
    :relative_paths => {:input => "alt/input"})
  
  #
  # basic tests
  #
  
  def test_setup_with_options
    assert_equal @app, app
    assert_equal Tap::App.instance, app
    assert_equal File.expand_path("./alt/root/test_setup_with_options"), File.expand_path(app[:root])
    assert_equal File.expand_path("./alt/root/test_setup_with_options/alt/input"), File.expand_path(app[:input])
  end
end

class TapTestTest < Test::Unit::TestCase
  include Tap::Support
  include TapTestMethods
  acts_as_tap_test 
  
  #
  # basic tests
  #
  
  def test_setup
    assert runlist.empty?
    assert_equal @app, app
    assert_equal Tap::App.instance, app
    assert_equal File.expand_path(File.dirname(__FILE__) + "/tap_test/test_setup"), File.expand_path(app[:root])
    assert_equal File.expand_path(File.dirname(__FILE__) + "/tap_test/test_setup/input"), File.expand_path(app[:input])
  end
  
  def test_clear_runlist_empties_runlist
    runlist << 1
    assert !runlist.empty?
    
    clear_runlist
    assert runlist.empty?
  end
  
  def test_add_one_procedure_adds_input_to_runlist_and_returns_input_plus_one
    input = 1
    output = add_one.call(nil, input)
    assert_equal 2, output
    assert_equal [1], runlist
  end
  
  #
  # assert_audit test
  #
  
  def test_assert_audit_doc
    a = Audit.new(:a, 'a')
    b = Audit.new(:b, 'b', a)
  
    e = [[:a, 'a'], [:b, 'b']]
    assert_audit_equal(e, b)
  
    a = Audit.new(:a, 'a')
    b = Audit.new(:b, 'b', a)
  
    c = Audit.new(:c, 'c')
    d = Audit.new(:d, 'd', c)
    
    e = Audit.new(:e, 'e', [b,d])
    f = Audit.new(:f, 'f', e)
    
    eb = [[:a, "a"], [:b, "b"]]
    ed = [[:c, "c"], [:d, "d"]]
    expected = [[eb, ed], [:e, "e"], [:f, "f"]]
  
    assert_audit_equal(expected, f)
  end
  
  def test_assert_audit_equal
    a = Audit.new(:a, 'a')
    b = Audit.new(:b, 'b', a)
    
    e = [[:a, 'a'], [:b, 'b']]
    assert_audit_equal(e, b) 
    
    assert_raise(Test::Unit::AssertionFailedError) do
      e = [[:a, 'FLUNK'], [:b, 'b']]
      assert_audit_equal(e, b)
    end
  end
  
  #
  # with config 
  #
  
  def test_with_config_doc
    app = Tap::App.new(:quiet => true, :debug => false)
    with_config({:quiet => false}, app) do 
      assert !app.quiet
      assert !app.debug
    end
  
    assert app.quiet
    assert !app.debug
  end
  
  def test_nested_with_config
    with_config({:one => 'one', :two => 'two'}) do
      assert_equal 'one', app.config[:one]
      assert_equal 'two', app.config[:two]
      
      with_config({:one => 'two'}) do
        assert_equal 'two', app.config[:one]
        assert_equal 'two', app.config[:two]
      end
      
      assert_equal 'one', app.config[:one]
      assert_equal 'two', app.config[:two]
    end
    
    assert_nil app.config[:one]
    assert_nil app.config[:two]
  end

  #
  # assert_files
  #
  
  def test_assert_files
    t = Tap::FileTask.intern do |task, input_file, output_file|
      task.prepare(output_file)
      File.open(output_file, "wb") {|f| f << "#{File.read(input_file)}content"}
      output_file
    end
  
    was_in_block = false
    with_config do
      assert_files do |input_files|
        was_in_block = true
        
        input_files.collect do |input_file|
          output_file = method_root.filepath(:output, File.basename(input_file))
          t.execute(input_file, output_file)
        end
      end
    end
    
    assert was_in_block
  end
    
end


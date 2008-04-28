require  File.dirname(__FILE__) + '/../tap_test_helper'
require 'tap/test'

class TestSetupTest < Test::Unit::TestCase
  acts_as_tap_test(
    :root => "alt/root", 
    :directories => {:input => "alt/input"})
  
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

class TapMethodsTest < Test::Unit::TestCase
  include TapTestMethods
  acts_as_tap_test 
  
  #
  # basic tests
  #
  
  def test_setup
    assert runlist.empty?
    assert_equal @app, app
    assert_equal Tap::App.instance, app
    assert_equal File.expand_path(File.dirname(__FILE__) + "/tap_methods/test_setup"), File.expand_path(app[:root])
    assert_equal File.expand_path(File.dirname(__FILE__) + "/tap_methods/test_setup/input"), File.expand_path(app[:input])
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
    a = Tap::Support::Audit.new
    a._record(:a, 'a')
    a._record(:b, 'b')
  
    e = ExpAudit[[:a, 'a'], [:b, 'b']]
    assert_audit_equal(e, a)

    a = Tap::Support::Audit.new
    a._record(:a, 'a')
    a._record(:b, 'b')
  
    e = ExpAudit[
         lambda {|source, value| source == :a && value == 'a'},
        [:b, 'b']]
    assert_audit_equal(e, a)
  
    a = Tap::Support::Audit.new
    a._record(:a, 'a')
    a._record(:b, 'b')
  
    b = Tap::Support::Audit.new
    b._record(:c, 'c')
    b._record(:d, 'd')
  
    c = Tap::Support::Audit.merge(a,b)
    c._record(:e, 'e')
    c._record(:f, 'f')
  
    ea = ExpAudit[[:a, "a"], [:b, "b"]]
    eb = ExpAudit[[:c, "c"], [:d, "d"]]
    e = ExpAudit[ExpMerge[ea, eb], [:e, "e"], [:f, "f"]]
  
    assert_audit_equal(e, c)
    
    ea = ExpAudit[[:a, "a"], [:b, "FLUNK"]]
    eb = ExpAudit[[:c, "c"], [:d, "d"]]
    e = ExpAudit[ExpMerge[ea, eb], [:e, "e"], [:f, "f"]]
  
    flunked = false
    begin
      assert_audit_equal(e, c)
    rescue
      assert $!.message =~ /unequal record 0:0:1\./
      flunked = true
    end
    
    assert flunked
    
    assert_equal ExpAudit[ExpMerge[ea, eb], [:e, "e"], [:f, "f"]], e
    assert_equal ExpMerge[ea, eb], e[0]
    assert_equal ExpAudit[[:a, "a"], [:b, "FLUNK"]], e[0][0]
    assert_equal [:b, "FLUNK"], e[0][0][1]
  end
  
  def test_assert_audit_equal
    a = Tap::Support::Audit.new(nil, nil)
    a._record(:a, 'a')
    a._record(:b, 'b')
    
    e = ExpAudit[[nil, nil], [:a, 'a'], [:b, 'b']]
    assert_audit_equal(e, a) 
    
    begin
      e = ExpAudit[[nil, nil], [:a, 'FLUNK'], [:b, 'b']]
      assert_audit_equal(e, a)
      
      flunk "audits should not have been equal"
    rescue
      assert_equal "unequal record 1.\n<[:a, \"FLUNK\"]> expected but was\n<[:a, \"a\"]>.", $!.message
    end
  end
  
  def test_assert_audit_equal_with_procs
    a = Tap::Support::Audit.new(nil, nil)
    a._record(:a, 'a')
    a._record(:b, 'b')
    
    e = ExpAudit[
      lambda {|source, value| source == nil && value == nil}, 
      lambda {|source, value| source == :a && value == 'a'}, 
      lambda {|source, value| source == :b && value == 'b'}]
    assert_audit_equal(e, a) 
    
    begin
      e = ExpAudit[
        lambda {|source, value| source == nil && value == nil}, 
        lambda {|source, value| source == :a && value == 'FLUNK'}, 
        lambda {|source, value| source == :b && value == 'b'}]
      assert_audit_equal(e, a)
      
      flunk "audits should not have been equal"
    rescue
      assert_equal "unconfirmed record 1.\n<false> is not true.", $!.message
    end
  end
  
  def test_assert_audit_equal_for_merge
    a = Tap::Support::Audit.new(nil, nil)
    a._record(:a, 'a')
    a._record(:b, 'b')
  
    b = Tap::Support::Audit.new(nil, nil)
    b._record(:c, 'c')
    b._record(:d, 'd')
    
    c = Tap::Support::Audit.merge(a,b)
    c._record(:e, 'e')
    c._record(:f, 'f')
    
    ea = ExpAudit[[nil, nil], [:a, "a"], [:b, "b"]]
    eb = ExpAudit[[nil, nil], [:c, "c"], [:d, "d"]]
    e = ExpAudit[ExpMerge[ea, eb], [:e, "e"], [:f, "f"]]
  
    assert_audit_equal(e, c)
    
    begin
      ea = ExpAudit[[nil, nil], [:a, "FLUNK"], [:b, "b"]]
      eb = ExpAudit[[nil, nil], [:c, "c"], [:d, "d"]]
      e = ExpAudit[ExpMerge[ea, eb], [:e, "e"], [:f, "f"]]
      assert_audit_equal(e, c)
      flunk "audits should not have been equal"
    rescue
      assert_equal "unequal record 0:0:1.\n<[:a, \"FLUNK\"]> expected but was\n<[:a, \"a\"]>.", $!.message
    end
  end
  
  def new_audit(letter, n=0)
    a = Tap::Support::Audit.new(nil, nil)
    1.upto(n) {|i| a._record(letter, "#{letter}#{i}")}
    a
  end
  
  def test_assert_audit_equal_for_nested_merge_with_procs
    a = new_audit(:a, 1)
    b = new_audit(:b, 1)
    c = Tap::Support::Audit.merge(a,b)
    1.upto(1) {|i| c._record(:c, "c#{i}")}
    
    d = new_audit(:d, 1)
    e = new_audit(:e, 1)
    f = Tap::Support::Audit.merge(d, e, 'x1', 'y1', 'z1')
    1.upto(1) {|i| f._record(:f, "f#{i}")}
    
    g = Tap::Support::Audit.merge(c, f)
    1.upto(1) {|i| g._record(:g, "g#{i}")}
    
    ea = ExpAudit[[nil, nil], [:a, 'a1']]
    eb = ExpAudit[[nil, nil], [:b, 'b1']]
    ec = ExpAudit[ExpMerge[ea, eb], lambda {|source, value| source == :c && value == 'c1'}]
    
    ed = ExpAudit[[nil, nil], [:d, 'd1']]
    ee = ExpAudit[[nil, nil], [:e, 'e1']]
    ex1 = ExpAudit[lambda {|source, value| source == nil && value == 'x1'}]
    ey1 = ExpAudit[[nil, 'y1']]
    ez1 = ExpAudit[[nil, 'z1']]
    ef = ExpAudit[ExpMerge[ed, ee, ex1, ey1, ez1], [:f, 'f1']]
    
    eg = ExpAudit[ExpMerge[ec, ef], [:g, 'g1']]
    assert_audit_equal(eg, g)
    
    begin
      ea = ExpAudit[[nil, nil], [:a, 'a1']]
      eb = ExpAudit[[nil, nil], [:b, 'b1']]
      ec = ExpAudit[ExpMerge[ea, eb], lambda {|source, value| source == :c && value == 'c1'}]

      ed = ExpAudit[[nil, nil], [:d, 'd1']]
      ee = ExpAudit[[nil, nil], [:e, 'e1']]
      ex1 = ExpAudit[lambda {|source, value| source == nil && value == 'FLUNK'}]
      ey1 = ExpAudit[[nil, 'y1']]
      ez1 = ExpAudit[[nil, 'z1']]
      ef = ExpAudit[ExpMerge[ed, ee, ex1, ey1, ez1], [:f, 'f1']]

      eg = ExpAudit[ExpMerge[ec, ef], [:g, 'g1']]
      assert_audit_equal(eg, g)
    rescue
      assert_equal "unconfirmed record 0:1:0:2:0.\n<false> is not true.", $!.message
    end
  end
  
  # TODO -- test length check for assert_audit_equal
  
  #
  # with options 
  #
  
  def test_with_options_doc
    app.options.one = 1
    app.options.two = 2
    
    assert_equal({:one => 1, :two => 2}, app.options.marshal_dump)
    with_options(:one => 'one', :quiet => false) do
      assert_equal({:one => 'one', :two => 2, :debug => true, :quiet => false}, app.options.marshal_dump)
    end
    assert_equal({:one => 1, :two => 2}, app.options.marshal_dump)
  end
  
  def test_with_options_merges_new_and_default_options_with_existing_for_block
    app.options.one = 1
    app.options.two = 2
    
    assert_equal({:one => 1, :two => 2}, app.options.marshal_dump)
    with_options(:one => 'one') do
      assert_equal({:one => 'one', :two => 2, :debug => true, :quiet => true}, app.options.marshal_dump)
    end
    assert_equal({:one => 1, :two => 2}, app.options.marshal_dump)
  end
  
  def test_with_options_does_not_merge_if_merge_with_existing_is_false
    app.options.one = 1
    app.options.two = 2
    
    assert_equal({:one => 1, :two => 2}, app.options.marshal_dump)
    with_options({:one => 'one'}, app, false) do
      assert_equal({:one => 'one', :debug => true, :quiet => true}, app.options.marshal_dump)
    end
    assert_equal({:one => 1, :two => 2}, app.options.marshal_dump)
  end
  
  #
  # with config 
  #
  
  def test_with_config_doc
    app = Tap::App.new(:directories => {:dir => 'dir', :alt => 'alt_dir'})
    tmp_config = {
      :directories => {:alt => 'another', :new => 'new_dir'},
      :options => {:one => 1, :quiet => false}}
  
    with_config(tmp_config, app) do 
      assert_equal({:dir => 'dir', :alt => 'another', :new => 'new_dir'}, app.directories)        
      assert_equal({:one => 1, :debug => true, :quiet => false}, app.options.marshal_dump)
    end
    assert_equal({:dir => 'dir', :alt => 'alt_dir'}, app.directories)
    assert_equal({}, app.options.marshal_dump)
  end
  
  def test_with_config_merges_new_config_with_existing_for_block
    config = {
      :root => File.expand_path("root"),
      :directories => {:dir => 'dir', :alt => 'alt_dir'},
      :options => {:one => 1, :two => 2}}
    logger_config ={
        :device => app.logger.logdev.dev,
        :level => app.logger.level,
        :datetime_format => app.logger.datetime_format}
        
    full_config = config.merge(
        :absolute_paths => {},
        :logger => logger_config) 
    modified_config = {
      :root => File.expand_path("root"),
      :directories => {:dir => 'another', :new => 'new_dir', :alt => 'alt_dir'},
      :options => {:one => 'one', :two => 2, :debug => true, :quiet => true},
      :absolute_paths => {:abs => File.expand_path('abs')},
      :logger => logger_config}
    
    app.reconfigure(full_config)
   
    assert_equal(full_config, app.config)
    with_config(
      :directories => {:dir => 'another', :new => 'new_dir'},
      :options => {:one => 'one'},
      :absolute_paths => {:abs => 'abs'}
    ) do
      assert_equal(modified_config, app.config)
    end
    assert_equal(full_config, app.config)
  end
  
  def test_with_config_does_not_merge_if_merge_with_existing_is_false
    config = {
      :root => File.expand_path("root"),
      :directories => {:dir => 'dir', :alt => 'alt_dir'},
      :options => {:one => 1, :two => 2}}
    logger_config ={
        :device => app.logger.logdev.dev,
        :level => app.logger.level,
        :datetime_format => app.logger.datetime_format}
        
    full_config = config.merge(
        :absolute_paths => {},
        :logger => logger_config) 
    modified_config = {
      :root => File.expand_path("root"),
      :directories => {:dir => 'another', :new => 'new_dir'},
      :options => {:one => 'one', :debug => true, :quiet => true},
      :absolute_paths => {:abs => File.expand_path('abs')},
      :logger => logger_config}
    
    app.reconfigure(full_config)
   
    assert_equal(full_config, app.config)
    with_config(
      {:directories => {:dir => 'another', :new => 'new_dir'},
      :options => {:one => 'one'},
      :absolute_paths => {:abs => 'abs'}},
      app,
      false
    ) do
      assert_equal(modified_config, app.config)
    end
    assert_equal(full_config, app.config)
  end
  
  def test_nested_with_config
    with_config(:options => {:one => 'one'}) do
      assert_equal 'one', app.options.one
      with_config(:options => {:one => 'two'}) do
        assert_equal 'two', app.options.one
      end
      assert_equal 'one', app.options.one
    end
  end

  #
  # assert_files
  #
  
  def test_assert_files
    t = Tap::FileTask.new("task/name") do |task, input_file|
      output_file = task.filepath(:data, File.basename(input_file))
      content = "#{File.read(input_file)}content"
      
      assert_equal method_filepath(:output, "task/name", File.basename(input_file)), output_file
      
      task.prepare(output_file)
      File.open(output_file, "wb") {|f| f << content}
      output_file
    end
  
    was_in_block = false
    with_config :options => {:debug => true}, :directories => {:data => 'output'} do
      assert_files do |input_files|
        was_in_block = true
        input_files.collect {|input_file| t.execute(input_file)}
      end
    end
    
    assert was_in_block
  end
    
end


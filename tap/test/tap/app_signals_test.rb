require File.expand_path('../../tap_test_helper', __FILE__)
require 'tap/app'
require 'tap/test/unit'

class AppSignalsTest < Test::Unit::TestCase
  extend Tap::Test
  acts_as_tap_test
  acts_as_file_test
  
  App = Tap::App
  
  #
  # exe test
  #
  
  def test_exe_executes_obj_with_inputs
    runlist = []
    n = lambda {|input| runlist << input }
    app.set(0, n)
    
    signal :exe, [0, 1,2,3]
    signal :exe, [0, 4,5,6]
    assert_equal [], app.queue.to_a
    assert_equal [[1,2,3], [4,5,6]], runlist
  end
  
  def test_exe_raises_error_for_unknown_obj
    err = assert_raises(RuntimeError) { signal :exe, [0] }
    assert_equal "no object set to: 0", err.message
  end
  
  #
  # enq test
  #
  
  def test_enq_enques_obj_with_inputs
    n = lambda {}
    app.set(0, n)
    signal :enq, [0, 1,2,3]
    signal :enq, [0, 4,5,6]
    assert_equal [[n, [1,2,3]], [n, [4,5,6]]], app.queue.to_a
  end
  
  def test_enq_raises_error_for_unknown_obj
    err = assert_raises(RuntimeError) { signal :enq, [0] }
    assert_equal "no object set to: 0", err.message
  end
  
  #
  # pq test
  #
  
  def test_pq_priority_enques_obj_with_inputs
    n = lambda {}
    app.set(0, n)
    signal :pq, [0, 1,2,3]
    signal :pq, [0, 4,5,6]
    assert_equal [[n, [4,5,6]], [n, [1,2,3]]], app.queue.to_a
  end
  
  def test_pq_raises_error_for_unknown_obj
    err = assert_raises(RuntimeError) { signal(:pq, [0]) }
    assert_equal "no object set to: 0", err.message
  end
  
  #
  # set test
  #
  
  class SetClass
    class << self
      def build(spec, app)
        obj = new(spec)
        obj.build_method = :build
        obj
      end
      
      def parse(argv, app)
        obj = new(argv)
        obj.build_method = :parse
        obj
      end
    end
    
    attr_reader :args
    attr_accessor :build_method
    
    def initialize(args=nil)
      @args = args
    end
  end
  
  def test_set_instantiates_and_stores_obj_by_var
    obj = signal(:set, ['var', SetClass])
    assert_equal SetClass, obj.class
    assert_equal({'var' => obj}, app.objects)
  end
  
  def test_set_does_not_set_obj_for_nil_var
    obj = signal(:set, [nil, SetClass])
    assert_equal({}, app.objects)
  end
  
  def test_set_builds_with_hash_spec
    obj = signal(:set, 'class' => SetClass, 'spec' => {'key' => 'alt'})
    assert_equal({'key' => 'alt'}, obj.args)
    assert_equal :build, obj.build_method
  end
  
  def test_set_parses_with_array_spec
    obj = signal(:set, 'class' => SetClass, 'spec' => ['arg'])
    assert_equal(['arg'], obj.args)
    assert_equal :parse, obj.build_method
  end
  
  def test_set_stores_obj_by_multiple_var_if_specified
    obj = signal(:set, 'class' => SetClass)
    assert_equal({}, app.objects)
    
    obj = signal(:set, 'var' => ['a', 'b'], 'class' => SetClass)
    assert_equal({'a' => obj, 'b' => obj}, app.objects)
  end
  
  def test_set_raises_error_for_unresolvable_class
    err = assert_raises(RuntimeError) { signal(:set, ['var', 'Non::Existant']) }
    assert_equal "uninitialized constant: \"Non::Existant\"", err.message
  end
  
  #
  # get test
  #
  
  def test_get_returns_specified_object
    o = Object.new
    app.set(0, o)
    assert_equal o, signal(:get, [0])
  end
  
  def test_get_returns_nil_for_missing_object
    assert_equal nil,  signal(:get, [1])
  end
  
  #
  # bld test
  #
  
  def test_bld_builds_with_hash_spec
    obj = signal(:bld, 'class' => SetClass, 'spec' => {'key' => 'alt'})
    assert_equal({'key' => 'alt'}, obj.args)
    assert_equal :build, obj.build_method
  end
  
  def test_bld_parses_with_array_spec
    obj = signal(:bld, 'class' => SetClass, 'spec' => ['arg'])
    assert_equal(['arg'], obj.args)
    assert_equal :parse, obj.build_method
  end
  
  #
  # use test
  #
  
  class UseClass
    class << self
      def build(spec={}, app=Tap::App.current)
        new(app.stack)
      end
    end
    
    attr_reader :stack
    def initialize(stack)
      @stack = stack
    end
  end
  
  def test_use_builds_and_sets_middleware
    obj = signal(:use, 'class' => UseClass)
    assert_equal UseClass, obj.class
    assert_equal [obj], app.middleware
  end
  
  #
  # configure test
  #
  
  def test_configure_reconfigures_app
    assert_equal false, app.verbose
    assert_equal app.config, signal('configure', ['--verbose'])
    assert_equal true, app.verbose
  end
  
  def test_configure_reconfigures_app_from_hash_args
    assert_equal false, app.verbose
    assert_equal app.config, signal('configure', {'verbose' => true})
    assert_equal true, app.verbose
  end
  
  #
  # reset test
  #
  
  def test_reset_resets_app
    n = lambda {|input|}
    app.enq n
    app.set(0, n)
    app.use UseClass
    
    assert_equal false, app.objects.empty?
    assert_equal 1, app.queue.size
    assert_equal 1, app.middleware.size
    
    assert_equal app, signal(:reset)
    
    assert_equal true, app.objects.empty?
    assert_equal 0, app.queue.size
    assert_equal 0, app.middleware.size
  end
  
  #
  # run test
  #
  
  def test_run_runs_app
    was_in_block = false
    n = lambda {|input| was_in_block = true }
    app.enq n
    
    assert_equal app, signal(:run)
    assert_equal 0, app.queue.size
    assert_equal true, was_in_block
  end
  
  #
  # stop test
  #
  
  def test_stop_stops_app
    was_in_a = false
    a = lambda do |input|
      was_in_a = true
      assert_equal app, signal(:stop)
      assert_equal App::State::STOP, app.state
    end
    
    was_in_b = false
    b = lambda do |input|
      was_in_b = true
    end
    
    app.enq a
    app.enq b
    app.run
    
    assert_equal true, was_in_a
    assert_equal false, was_in_b
    assert_equal 1, app.queue.size
  end
  
  #
  # terminate test
  #
  
  def test_terminate_terminates_app
    was_in_a = false
    a = lambda do |input|
      was_in_a = true
      assert_equal app, signal(:terminate)
      assert_equal App::State::TERMINATE, app.state
    end
    
    was_in_b = false
    b = lambda do |input|
      was_in_b = true
    end
    
    app.enq a
    app.enq b
    app.run
    
    assert_equal true, was_in_a
    assert_equal false, was_in_b
    assert_equal 1, app.queue.size
  end
  
  #
  # info test
  #
  
  def test_info_returns_info_string
    assert_equal app.info, signal(:info)
  end
  
  #
  # serialize test
  #
  
  def test_serialize_writes_signals_to_path
    path = method_root.prepare('output.yml')
    assert_equal app, signal(:serialize, [path])
    
    assert_equal File.read(path), YAML.dump(app.serialize)
  end
  
  def test_serialize_allows_bare_option
    path = method_root.prepare('output.yml')
    
    assert_equal app, signal(:serialize, [path, '--bare'])
    assert_equal File.read(path), YAML.dump(app.serialize(true))
    
    assert_equal app, signal(:serialize, [path, '--no-bare'])
    assert_equal File.read(path), YAML.dump(app.serialize(false))
  end
  
  def test_serialize_signature
    path = method_root.prepare('output.yml')
    
    assert_equal app, signal(:serialize, 'path' => path, 'bare' => true)
    assert_equal File.read(path), YAML.dump(app.serialize(true))
    
    assert_equal app, signal(:serialize, 'path' => path, 'bare' => false)
    assert_equal File.read(path), YAML.dump(app.serialize(false))
  end
  
  #
  # import test
  #
  
  def test_import_calls_serialized_signals
    assert_equal false, app.verbose
    path = method_root.prepare('output.yml') {|io| io << YAML.dump(app.serialize(false)) }
    
    app.verbose = true
    assert_equal app, signal(:import, [path])
    assert_equal false, app.verbose
  end

  #
  # help test
  #
  
  def test_help_signal_lists_signals
    list = app.call('sig' => 'help', 'args' => [])
    
    assert list =~ /\/set\s+# set or unset objects/
    assert list =~ /\/get\s+# get objects/
  end
  
  def test_help_with_arg_lists_signal_help
    help = app.call('sig' => 'help', 'args' => ['set'])
    assert help =~ /Tap::App::Set -- set or unset objects/
    
    help = app.call('sig' => 'help', 'args' => {'sig' => 'set'})
    assert help =~ /Tap::App::Set -- set or unset objects/
  end
end

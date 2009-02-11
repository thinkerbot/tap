require File.join(File.dirname(__FILE__), '../tap_test_helper')

class ClassReferenceTest < Test::Unit::TestCase 
  acts_as_script_test

  TAP_EXECUTABLE_PATH = File.expand_path(File.dirname(__FILE__) + "/../../bin/rap")

  def default_command_path
    %Q{ruby "#{TAP_EXECUTABLE_PATH}"}
  end
  
  #
  # Configurable test
  #
  
  class ConfigClass
    include Configurable
    
    config :key, 'value' do |input|
      input.upcase
    end
    
    def initialize
      initialize_config
    end
  end
  
  def test_configurable
    c = ConfigClass.new
    assert_equal 'VALUE', c.key

    c.config[:key] = 'new value'
    assert_equal 'NEW VALUE', c.key

    c.key = 'another value'
    assert_equal 'ANOTHER VALUE', c.config[:key]
  end
  
  #
  # Validation test
  #
  
  class ValidatingClass
    include Configurable

    config :int, 1, &c.integer                 # assures the input is an integer
    config :int_or_nil, 1, &c.integer_or_nil   # integer or nil only
    config :array, [], &c.array                # you get the idea
  end
  
  def test_validation
    vc = ValidatingClass.new

    vc.array = [:a, :b, :c]
    assert_equal [:a, :b, :c], vc.array

    vc.array = "[1, 2, 3]"
    assert_equal [1, 2, 3], vc.array

    assert_raises(Configurable::Validation::ValidationError) { vc.array = "string" }
  end
  
  #
  # Lazydoc test
  #

  def test_lazydoc
    lazydoc_file = method_root.prepare(:tmp, 'one') do |file|
      file << %Q{
# Const::Name::key value
# 
# This is an extended,
# multiline comment.
#
}
    end

    lazydoc = Lazydoc[lazydoc_file]
    lazydoc.resolve
    
    assert_equal "value", lazydoc['Const::Name']['key'].value   
    assert_equal "This is an extended, multiline comment.", lazydoc['Const::Name']['key'].comment
    
    ####
    another_lazydoc_file = method_root.prepare(:tmp, 'two') do |file|
      file << %Q{
# Sample::manifest a summary of the task
class Sample < Tap::Task
  config :key, 'value'   # a simple configuration

  def process(a, b='B', *c)
  end
end
}
    end
    
    load(another_lazydoc_file)
    assert_equal "a summary of the task", Sample::manifest.to_s
    assert_equal "A B='B' C...", Sample::args.to_s

    key = Sample.configurations[:key]
    assert_equal "a simple configuration", key.attributes[:desc].to_s
  end
  
  #
  # Task test
  #
  
  def test_task
    t = Tap::Task.intern {|task| 1 + 2 }
    assert_equal 3, t.process

    t = Tap::Task.intern {|task, x, y| x + y }
    assert_equal 3, t.process(1, 2)

    runlist = []
    t1 = Tap::Task.intern(:key => 'one') do |task, input| 
      runlist << task
      "#{input}:#{task.config[:key]}"
    end

    t0 = Tap::Task.intern {|task| runlist << task }
    t1.depends_on(t0)

    t2 = Tap::Task.intern do |task, input|
      runlist << task
      "#{input}:two"
    end
    t1.sequence(t2)
    
    t1.enq('input')
    
    app = Tap::App.instance
    app.run
    
    assert_equal [t0, t1, t2], runlist
    assert_equal ["input:one:two"], app.results(t2)

    t1.name = 'un'
    t2.name = 'deux'

    result = app._results(t2)[0].dump
    expected = %Q{o-[] "input"
o-[un] "input:one"
o-[deux] "input:one:two"
}
    
    assert_equal expected, result
  end
  
  #
  # Root test
  #
  
  def test_root
    root = Tap::Root.new '/path/to/root'
    assert_equal File.expand_path('/path/to/root'), root.root
    assert_equal File.expand_path('/path/to/root/config'), root['config']
    assert_equal File.expand_path('/path/to/root/config/sample.yml'), root.filepath('config', 'sample.yml')
  end
  
  #
  # App test
  #
  
  def test_app
    log = StringIO.new
    app = Tap::App.instance
    app.logger = Logger.new(log)
    app.logger.formatter = lambda do |severity, time, progname, msg|
      "  %s %s: %s\n" % [severity[0,1], progname, msg]
    end

    t = Tap::Task.intern {|task, *inputs| inputs }
    t.log 'action', 'to app'
    log.string                 # =>  "  I action: to app\n"

    t.enq(1)
    t.enq(2,3)

    assert_equal [[t, [1]], [t, [2,3]]], app.queue.to_a
    app.run
    assert_equal [[1], [2,3]], app.results(t)
  end
end
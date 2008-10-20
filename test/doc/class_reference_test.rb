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
    include Tap::Support::Configurable
    
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
    include Tap::Support::Configurable

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

    assert_raise(Tap::Support::Validation::ValidationError) { vc.array = "string" }
  end
  
  #
  # Lazydoc test
  #
  
  def test_lazydoc
    lazydoc_file = method_tempfile('lazydoc') do |file|
      file << %Q{
# Name::Space::key value
# 
# This documentation
# gets parsed.
#

# Name::Space::another another value
# This gets parsed.
# Name::Space::another-
#
# This does not.
}
    end

    lazydoc = Tap::Support::Lazydoc[lazydoc_file]
    lazydoc.resolve

    assert_equal "This documentation gets parsed.", lazydoc['Name::Space']['key'].to_s
    assert_equal "another value", lazydoc['Name::Space']['another'].value
    
    ####
    another_lazydoc_file = method_tempfile('lazydoc') do |file|
      file << %Q{# documentation
# for the method
def method
end
}
    end
    
    lazydoc = Tap::Support::Lazydoc[another_lazydoc_file]
    code_comment = lazydoc.register(2)
    lazydoc.resolve

    assert_equal "def method", code_comment.subject
    assert_equal "documentation for the method", code_comment.to_s
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

    t3 = t1.initialize_batch_obj(:key => 'three')
    assert_equal [t1, t3], t1.batch
    
    t1.enq('input')
    
    app = Tap::App.instance
    app.run
    
    assert_equal [t0, t1, t2, t3, t2], runlist
    assert_equal ["input:one:two", "input:three:two"], app.results(t2)

    t1.name = 'un'
    t2.name = 'deux'
    t3.name = 'trois'

    result = app._results(t2).collect do |_result|
      _result._to_s
    end.join("---\n")
    expected = %Q{o-[] "input"
o-[un] "input:one"
o-[deux] "input:one:two"
---
o-[] "input"
o-[trois] "input:three"
o-[deux] "input:three:two"
}
    
    assert_equal expected, result
  end
  
  #
  # Root test
  #
  
  def test_root
    root = Tap::Root.new '/path/to/root'
    assert_equal '/path/to/root', root.root
    assert_equal '/path/to/root/config', root['config']
    assert_equal '/path/to/root/config/sample.yml', root.filepath('config', 'sample.yml')
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
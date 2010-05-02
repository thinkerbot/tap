require File.expand_path('../../../../test_helper.rb', __FILE__) 
require 'tap/tasks/stream/yaml'
require 'stringio'

class StreamYamlTest < Test::Unit::TestCase
  include Tap::Tasks
  acts_as_tap_test
  acts_as_shell_test(SH_TEST_OPTIONS)

  def test_stream_yaml_documentation
    path = method_root.prepare(:tmp, 'data.yml') do |io|
      io << %q{--- 
:sym
--- 
- 1
- 2
- 3
--- 
key: value
}
    end

    sh_test %Q{
% tap stream/yaml --file "#{path}" -: inspect
:sym
[1, 2, 3]
{"key"=>"value"}
}
  end
    
  #
  # load test
  #
  
  def test_stream_yaml_loads_io_as_YAML
    io = StringIO.new "--- \nkey: value\n"
    assert_equal({'key' => 'value'}, Stream::Yaml.new.load(io))
  end
  
  def test_stream_yaml_loads_multiple_documents
    io = StringIO.new %Q{--- :one\n--- :two\n--- :three}
    
    results = []
    task = Stream::Yaml.new
    task.on_complete {|result| results << result }
    task.enq(io)
    
    app.run
    assert_equal([:one, :two, :three], results)
  end
  
end
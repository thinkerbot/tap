require File.join(File.dirname(__FILE__), '../../../tap_test_helper')
require 'tap/tasks/stream/yaml'
require 'stringio'

class StreamYamlTest < Test::Unit::TestCase
  include Tap::Tasks
  acts_as_tap_test
  acts_as_shell_test(SH_TEST_OPTIONS)

  #
  # load test
  #
  
  def test_stream_yaml_loads_io_as_YAML
    io = StringIO.new "--- \nkey: value\n"
    assert_equal({'key' => 'value'}, Stream::Yaml.new.load(io))
  end
  
  def test_stream_yaml_loads_multiple_documents
    io = StringIO.new %Q{--- :one\n--- :two\n--- :three}
    Stream::Yaml.new.enq(io)
    
    results = []
    app.on_complete {|result| results << result }
    app.run
    
    assert_equal([:one, :two, :three], results)
  end
  
  def test_stream_yaml_loads_multiple_documents_from_file
    path = method_root.prepare(:tmp, 'data.yml') do |io|
      YAML.dump(:sym, io)
      YAML.dump([1,2,3], io)
      YAML.dump({:key => 'value'}, io)
    end
    
    sh_test %Q{
% tap run -- stream/yaml "#{path}" --file --: inspect
:sym
[1, 2, 3]
{:key=>\"value\"}
}
  end
end
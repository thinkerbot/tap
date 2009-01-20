require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/server'
require 'tap/test/regexp_escape'
require 'rack/mock'

class RunTest < Test::Unit::TestCase
  
  acts_as_tap_test
 
  #
  # setup
  #
  
  attr_accessor :server
  
  def setup
    super
    
    env = Tap::Env.instantiate(method_root)
    env.reconfigure :root => {
      :absolute_paths => {
        :template => File.expand_path(File.dirname(__FILE__) + "/../../template")}}
        
    @server = Tap::Server.new(env)
  end
  
  def teardown
    @server.env.deactivate
    Tap::Env.instances.clear
    
    super
  end
  
  #
  # run test
  #
  
  def test_run_template_renders_schema
    method_root.prepare(:lib, 'sample.rb') do |file|
      file << %Q{
# ::manifest a sample task
# A long description
class Sample < Tap::Task
  config :key, 'value'
  def process(a, b='B', *c)
  end
end
}
    end
    
    schema = Tap::Support::Parser.new("sample").schema
    assert_alike server.env.render('run.erb', :schema => schema), Tap::Test::RegexpEscape.new(%q{
  <li id="node_0" class="node">
    <!-- controls -->
    <ul>
      <li><input id="target_checkbox_0" class="target_checkbox" name="target" value="0" type="checkbox" /></li>
      <li><input id="source_checkbox_0" class="source_checkbox" name="source" value="0" type="checkbox" /></li>
    </ul>

    <span class="class">Sample</span>: 
    <span class="summary">a sample task</span>
    <pre>A long description</pre>
    
    <!-- tasc identifier -->
    <input name="nodes[0][0]" type="hidden" value="sample" />
    
    <ul>
    <!-- inputs -->
    <li class="input">
    <input class="value" name="nodes[0][1]%w" value="" />
    <span class="name">A B='B' C...</span>
    </li>

    <!-- configurations -->
    <li class="config">
    <input class="key" name="nodes[0][2]" type="hidden" value="--key" />
    <input class="value" name="nodes[0][2]" type="text" value="value" />
    <span class="name">key</span>:
    <span class="desc"></span> 
    </li>

    <!-- options -->
    <li class="options">
    <input class="key" name="nodes[0][2]" type="hidden" value="--name" />
    <input class="value" name="nodes[0][2]" value="sample" />
    <span class="name">Name</span>
    </li>
    
    <!--
    <input class="globalize" name="nodes[0][2]" type="checkbox" value="--*0" />
    <span class="name">Globalize</span> -->
    
    </ul>
  </li> 
  <li class="round">
    <input name="rounds" value="--0" />
  </li> 
})
    
  end
end
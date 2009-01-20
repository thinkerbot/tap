require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/server'
require 'tap/test/regexp_escape'
require 'rack/mock'

class FunctionalServerTest < Test::Unit::TestCase
  
  acts_as_tap_test
  cleanup_dirs.concat [:public, :cgi]
    
  SERVER_ENV = Tap::Env.new(Tap::Root.new(File.dirname(__FILE__) + "/../.."))
  
  #
  # setup
  #
  
  attr_accessor :server_app, :server
  
  def setup
    super
    
    env = Tap::Env.instantiate(method_root)
    env.push SERVER_ENV
    env.activate
    @server_app = Tap::Server.new(env)
    @server = Rack::MockRequest.new(@server_app)
  end
  
  def teardown
    @server_app.env.deactivate
    Tap::Env.instances.clear
    
    super
  end
  
  def assert_body(res, str)
    assert_alike Tap::Test::RegexpEscape.new(str.strip, Regexp::MULTILINE), res.body
  end
  
  #
  # unknown url test
  #
  
  def test_server_returns_404_response_for_unknown_gets
    assert_body server.get('/unknown/url'), %q{
<p>
# 404 error<br/>
# Could not handle request:
</p>
<code><pre>
--- 
SERVER_NAME: example.org
PATH_INFO: /unknown/url
SCRIPT_NAME: ""
SERVER_PORT: "80"
QUERY_STRING: ""
REQUEST_METHOD: GET
--- 
:...:
</pre></code>
}
  end
  
  def test_server_returns_404_response_for_unknown_posts
    assert_body server.post('/unknown/url'), %q{
<p>
# 404 error<br/>
# Could not handle request:
</p>
<code><pre>
--- 
SERVER_NAME: example.org
PATH_INFO: /unknown/url
SCRIPT_NAME: ""
SERVER_PORT: "80"
QUERY_STRING: ""
REQUEST_METHOD: POST
--- 
:...:
</pre></code>
}
  end
  
  #
  # static page test
  #
  
  def test_server_returns_static_page_for_public_pages
    method_root.prepare(:public, 'page.html') {|file| file << "html page content"}
    method_root.prepare(:public, 'nested/page.html') {|file| file << "nested page content"}
    
    assert_equal "html page content", server.get('/page.html').body
    assert_equal "nested page content", server.get('/nested/page.html').body
  end
  
  def test_server_sets_mime_type_for_public_content
    method_root.prepare(:public, 'page.html') {|file| }
    method_root.prepare(:public, 'page.css') {|file| }
    
    assert_equal "text/html", server.get('/page.html')["Content-Type"]
    assert_equal "text/css", server.get('/page.css')["Content-Type"]
  end
  
  #
  # cgi page test
  #
  
  def test_server_runs_cgi_pages
    cgi_file = method_root.prepare(:cgi, 'page.rb') do |file| 
      file << %q{
        # this is adapted from one of the CGI documentation examples:
        # http://www.ruby-doc.org/core/classes/CGI.html
        
        require 'cgi'
        cgi = CGI.new("html3")  # add HTML generation methods
        cgi.out() do
          cgi.html() do
            cgi.body() do
              cgi.pre() do
                CGI::escapeHTML(
                  "\n" + {'params' => cgi.params}.to_yaml + "\n" +
                  ENV.collect() do |key, value|
                     "#{key}: #{value}\n"
                  end.join("")
                )
              end
            end
          end
        end
      }
    end
    
    assert_equal cgi_file, server_app.env.cgis.search('page.rb')
    assert_body server.get('/page.rb?key=one&key=two'), %q{
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2 Final//EN"><HTML><BODY><PRE>
--- 
params: 
  key: 
  - one
  - two

SERVER_NAME: example.org
rack.url_scheme: http
PATH_INFO: /page.rb
SCRIPT_NAME: 
SERVER_PORT: 80
QUERY_STRING: key=one&amp;key=two
REQUEST_METHOD: GET
</PRE></BODY></HTML>
}
  end

end

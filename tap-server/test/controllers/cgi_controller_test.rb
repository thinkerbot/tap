class CgiControllerTest
  #
  # cgi_attrs test
  #
  
  def test_cgi_attrs_returns_non_rack_pairs
    assert_equal({'key' => 'value'}, cgi_attrs({'key' => 'value', 'rack.key' => 'value'}))
  end
  
  #
  # with_ENV test
  #
  
  def test_with_ENV_sets_ENV_for_the_duration_of_the_block
    current = ENV.to_hash
    begin
      ENV.clear
      ENV['key'] = 'value'
      assert_equal({'key' => 'value'}, ENV.to_hash)
      
      was_in_block = false
      with_ENV('key' => 'alt', 'another' => 'value') do
        assert_equal({'key' => 'alt', 'another' => 'value'}, ENV.to_hash)
        was_in_block = true
      end
      assert was_in_block
      assert_equal({'key' => 'value'}, ENV.to_hash)
      
    ensure
      ENV.clear
      current.each_pair {|key, value| ENV[key] = value }
    end
  end
  
  def test_with_ENV_skips_non_string_values
    current = ENV.to_hash
    begin
      ENV.clear
      ENV['key'] = 'value'
      assert_equal({'key' => 'value'}, ENV.to_hash)
      
      was_in_block = false
      with_ENV('key' => 'alt', 'integer' => 1) do
        assert_equal({'key' => 'alt'}, ENV.to_hash)
        was_in_block = true
      end
      assert was_in_block
      assert_equal({'key' => 'value'}, ENV.to_hash)
      
    ensure
      ENV.clear
      current.each_pair {|key, value| ENV[key] = value }
    end
  end
  
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

    assert_equal cgi_file, server.env.cgis.search('page.rb')
    assert_body request.get('/cgi/page.rb?key=one&key=two'), %q{
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2 Final//EN"><HTML><BODY><PRE>
--- 
params: 
  key: 
  - one
  - two

SERVER_NAME: example.org
PATH_INFO: /cgi/page.rb
SCRIPT_NAME: 
SERVER_PORT: 80
QUERY_STRING: key=one&amp;key=two
REQUEST_METHOD: GET
</PRE></BODY></HTML>
}
  end
end
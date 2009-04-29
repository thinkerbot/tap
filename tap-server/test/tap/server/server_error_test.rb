require  File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/server/server_error'

class ServerErrorTest < Test::Unit::TestCase
  ServerError = Tap::Server::ServerError
  
  #
  # ServerError.response test
  #
  
  def test_class_response_formats_error_as_ServerError_response
    was_in_rescue = false
    
    begin
      raise ArgumentError, "message"
    rescue
      assert_equal [
        500,
        {'Content-Type' => 'text/plain'},
        ["500 ArgumentError: message\n#{$!.backtrace.join("\n")}"]
      ], ServerError.response($!)
      
      was_in_rescue = true
    end
    
    assert was_in_rescue
  end
  
  #
  # initialize test
  #
  
  def test_default_initialize
    e = ServerError.new
    assert_equal "500 Server Error", e.message
    assert_equal "500 Server Error", e.body
    assert_equal 500, e.status
    assert_equal({'Content-Type' => 'text/plain'}, e.headers)
  end
  
  def test_initialize
    e = ServerError.new("msg", 200, {:key => 'value'})
    assert_equal "msg", e.message
    assert_equal "msg", e.body
    assert_equal 200, e.status
    assert_equal({:key => 'value'}, e.headers)
  end
  
  #
  # response test
  #
  
  def test_response_formats_self_as_rack_response_array
    e = ServerError.new
    assert_equal [e.status, e.headers, [e.body]], e.response
  end
end
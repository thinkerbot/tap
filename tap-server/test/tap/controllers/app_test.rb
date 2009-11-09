# require  File.join(File.dirname(__FILE__), '../../tap_test_helper')
# require 'tap/controllers/app'
# 
# class Tap::Controllers::AppTest < Test::Unit::TestCase
#   acts_as_tap_test :cleanup_dirs => [:views, :public]
#   
#   attr_reader :server, :request
#   
#   def setup
#     super
#     @server = Tap::Server.new.bind(Tap::Controllers::Data)
#     @request = Rack::MockRequest.new(@server)
#     
#     @timeout = Time.now + 3
#     @timeout_error = false
#   end
#   
#   def env_config
#     config = super
#     config[:env_paths] = TEST_ROOT
#     config
#   end
#   
#   def teardown
#     super
#     flunk "timeout error" if @timeout_error
#   end
#   
#   def timeout?
#     if Time.now > @timeout
#       @timeout_error = true
#       true
#     else
#       false
#     end
#   end
#   
#   #
#   # state test
#   #
#   
#   def test_app_bq
#     was_in_block = false
#     app.bq { was_in_block = true }
#     
#     assert !was_in_block
#     app.run
#     assert was_in_block
#   end
#   
#   def test_state_returns_app_state
#     assert_equal "0", request.get("/state").body
#     
#     was_in_block = false
#     hold = true
#     app.bq do
#       was_in_block = true
#       sleep(0.01) while hold && !timeout?
#     end
#     
#     thread = Thread.new { app.run }
#     sleep(0.01)
#     
#     assert_equal "1", request.get("/state").body
#     assert_equal true, was_in_block
#     
#     hold = false
#     thread.join
#     
#     assert_equal "0", request.get("/state").body
#   end
#   
#   #
#   # info test
#   #
#   
#   def test_info_contains_app_info_and_controls
#     body = request.get("/info").body
#     assert body =~ /<form action="\/run".*?method="post">/
#     assert body =~ /\(READY\) queue: 0/
#   end
# 
#   #
#   # run test
#   #
#   
#   def test_run_redirects_to_info
#     assert_equal "/info", request.get("/run").headers['Location']
#   end
#   
#   def test_run_does_not_run_on_get
#     app.bq do 
#       flunk "app ran"
#     end
#     
#     request.get("/run")
#     assert_equal nil, server.thread
#     assert_equal 0, app.state
#   end
#   
#   def test_run_runs_on_post
#     was_in_block = false
#     hold = true
#     app.bq do 
#       was_in_block = true
#       sleep(0.1) while hold && !timeout?
#     end
#     
#     assert_equal "/info", request.post("/run").headers['Location']
#     assert_equal Thread, server.thread.class
#     
#     sleep(0.01)
#     
#     assert_equal 1, app.state
#     assert_equal true, was_in_block
#     
#     hold = false
#     server.thread.join
#     
#     # check thread is cleaned up when run completes
#     assert_equal nil, server.thread
#     assert_equal 0, app.state
#   end
#   
#   #
#   # stop test
#   #
#   
#   def test_stop_stops_a_running_app
#     was_in_block = false
#     node = app.node { was_in_block = true }
#     node.on_complete {|result| app.enq(node) unless timeout? }
#     app.enq(node)
#     
#     thread = Thread.new { app.run }
#     sleep(0.01)
#     
#     assert_equal 1, app.state
#     assert_equal true, was_in_block
#     
#     assert_equal "/info", request.post("/stop").headers['Location']
#     thread.join
#     
#     assert_equal 1, app.queue.size
#     assert_equal 0, app.state
#   end
#   
#   def test_stop_does_not_stop_unless_post
#     was_in_block = false
#     node = app.node do 
#       was_in_block = true
#       app.check_terminate
#     end
#     
#     node.on_complete {|result| app.enq(node) }
#     app.enq(node)
#     
#     thread = Thread.new { app.run }
#     sleep(0.01)
#     assert_equal "/info", request.get("/stop").headers['Location']
#     sleep(0.01)
#     
#     assert_equal 1, app.state
#     assert_equal true, was_in_block
#     
#     app.terminate
#     thread.join
#     
#     assert_equal 0, app.state
#   end
#   
#   #
#   # terminate test
#   #
#   
#   def test_terminate_terminates_a_running_app
#     was_in_block = false
#     app.bq do
#       was_in_block = true
#       while !timeout?
#         sleep(0.01)
#         app.check_terminate
#       end
#     end
#     
#     thread = Thread.new { app.run }
#     sleep(0.01)
#     
#     assert_equal 1, app.state
#     assert_equal true, was_in_block
#     
#     assert_equal "/info", request.post("/terminate").headers['Location']
#     thread.join
#     
#     assert_equal 0, app.state
#   end
#   
#   def test_terminate_does_not_terminate_unless_post
#     was_in_block = false
#     hold = true
#     app.bq do 
#       while hold && !timeout?
#         sleep(0.01)
#         app.check_terminate
#       end
#       was_in_block = true
#     end
#     
#     thread = Thread.new { app.run }
#     sleep(0.01)
#     assert_equal "/info", request.get("/terminate").headers['Location']
#     sleep(0.01)
#     
#     assert_equal 1, app.state
#     assert_equal false, was_in_block
#     
#     hold = false
#     thread.join
#     
#     assert_equal 0, app.state
#     assert_equal true, was_in_block
#   end
#   
#   #
#   # build test
#   #
#   
#   def test_build_returns_schema_form_on_get
#     body = request.get("/build").body
#     assert body =~ /<form action="\/build" method="post"/
#     assert body =~ /<input type="submit"/
#   end
#   
#   #
#   # enque test
#   #
#   
#   def test_enque_returns_enque_form_on_get
#     body = request.get("/enque").body
#     assert body =~ /<form action="\/enque" method="post"/
#     assert body =~ /<input type="submit" value="enque"/
#   end
#   
# end
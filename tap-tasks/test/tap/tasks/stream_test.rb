require File.join(File.dirname(__FILE__), '../../tap_test_helper.rb') 
require 'tap/tasks/stream'

class StreamTest < Test::Unit::TestCase
  acts_as_tap_test 
  acts_as_shell_test(SH_TEST_OPTIONS)
  
  include Tap::Tasks
  
  class LastStream < Stream
    attr_accessor :enqued

    def initialize(config={})
      @enqued = nil
      super(config)
    end

    def complete?(io, last)
      last == "last"
    end

    def reque(*inputs)
      @enqued = inputs
    end
  end

  def test_process_reques_self_unless_complete
    load = LastStream.new
    io = StringIO.new("one")

    assert_equal nil, load.enqued
    assert_equal("one", load.process(io))
    assert_equal [io], load.enqued

    load.enqued = nil
    io = StringIO.new("last")
    assert_equal("last", load.process(io))
    assert_equal nil, load.enqued
  end
end
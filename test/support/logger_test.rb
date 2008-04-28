require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/support/logger'
require 'stringio'

class LoggerTest < Test::Unit::TestCase
  include Tap

  #
  # logger tests
  #
  
  def test_logger
    output = StringIO.new('')
    logger = Logger.new(output).extend Support::Logger
    logger.datetime_format = '%H:%M:%S'
    logger.subject 'message'
    
    assert output.string =~ /^\s+I\[\d\d:\d\d:\d\d\]\s+subject\s+message/, output.string
  end
  
  def test_logdev_returns_the_log_device
    [StringIO.new(''), STDOUT].each do |device|
      logger = Logger.new(device)
      assert !logger.respond_to?(:logdev)
      
      logger.extend Support::Logger
      assert_equal Logger::LogDevice, logger.logdev.class
      assert_equal device, logger.logdev.dev
    end
  end
end
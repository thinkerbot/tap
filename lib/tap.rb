require 'rubygems'

require 'yaml'                   # expensive to load
require 'logger'
require 'ostruct'
require 'thread'
require 'erb'

autoload(:GetoptLong, 'getoptlong')
autoload(:PP, "pp")

# Apply version-specific patches
case RUBY_VERSION
when /^1.9/
  $: << File.dirname(__FILE__) + "/tap/patches/ruby19"
  
  # suppresses TDoc warnings
  $DEBUG_RDOC ||= nil 
end

# require 'active_support/clean_logger'

$:.unshift File.dirname(__FILE__)

require 'tap/constants'
class String # :nodoc:
  include Tap::Constants
end

require 'tap/env'
require 'tap/support/aggregator'
require 'tap/support/audit'
require 'tap/support/batchable_methods'
require 'tap/support/batchable'
require 'tap/support/executable'
require 'tap/support/executable_queue'
require 'tap/support/framework'
require 'tap/support/framework_methods'
require 'tap/support/logger'
require 'tap/support/run_error'
require 'tap/support/shell_utils'
require 'tap/support/validation'
require 'tap/app'
require 'tap/task'
require 'tap/file_task'
require 'tap/workflow'
require 'tap/dump'

# Apply platform-specific patches
# case RUBY_PLATFORM
# when 'java' 
# end
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

# Loading activesupport piecemeal like this cuts the tap load time in half.
gem 'activesupport'

require 'active_support/core_ext/array/extract_options.rb'
class Array #:nodoc:
  include ActiveSupport::CoreExtensions::Array::ExtractOptions
end
require 'active_support/core_ext/class.rb'
require 'active_support/core_ext/module.rb'
require 'active_support/core_ext/symbol.rb'
require 'active_support/core_ext/string.rb'
require 'active_support/core_ext/blank.rb'
require 'active_support/core_ext/hash/keys.rb'
require 'active_support/dependencies'
require 'active_support/clean_logger'
class Hash #:nodoc:
  include ActiveSupport::CoreExtensions::Hash::Keys
end

$:.unshift File.dirname(__FILE__)

require 'tap/constants'
class String # :nodoc:
  include Tap::Constants
end

require 'tap/support/aggregator'
require 'tap/support/audit'
require 'tap/support/batchable_methods'
require 'tap/support/batchable'
require 'tap/support/assignments'
require 'tap/support/class_configuration'
require 'tap/support/configurable'
require 'tap/support/configurable_methods'
require 'tap/support/executable'
require 'tap/support/executable_queue'
require 'tap/support/framework'
require 'tap/support/framework_methods'
require 'tap/support/logger'
require 'tap/support/run_error'
require 'tap/support/shell_utils'
require 'tap/support/validation'
require 'tap/env'
require 'tap/app'
require 'tap/task'
require 'tap/file_task'
require 'tap/workflow'
require 'tap/dump'

# Apply platform-specific patches
# case RUBY_PLATFORM
# when 'java' 
# end
require 'rubygems'

require 'yaml'                   # expensive to load
require 'logger'
require 'ostruct'
require 'thread'
require 'erb'

# Apply version-specific patches
case RUBY_VERSION
when /^1.9/
  $: << File.expand_path(File.dirname(__FILE__) + "/tap/patches/ruby19")
  
  # suppresses TDoc warnings
  $DEBUG_RDOC ||= nil 
end

$:.unshift File.expand_path(File.dirname(__FILE__))

require 'tap/constants'

# require in order...
require 'tap/env'
require 'tap/app'
require 'tap/task'
require 'tap/file_task'
require 'tap/workflow'

require 'tap/support/declarations'
Tap.extend Tap::Support::Declarations

# Apply platform-specific patches
# case RUBY_PLATFORM
# when 'java' 
# end
# Loading activesupport piecemeal like this cuts the tap load time in half.
gem 'activesupport'

require 'active_support/core_ext/array/extract_options.rb'
class Array #:nodoc:
  include ActiveSupport::CoreExtensions::Array::ExtractOptions
end
require 'active_support/core_ext/module.rb'
require 'active_support/core_ext/symbol.rb'
require 'active_support/core_ext/string.rb'
require 'active_support/core_ext/blank.rb'

require 'active_support/core_ext/hash/keys.rb'
class Hash #:nodoc:
  include ActiveSupport::CoreExtensions::Hash::Keys
end

require 'active_support/dependencies'

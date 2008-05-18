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

# 
# # Returns a list of arrays that receive load_paths on activate,
# # by default [$LOAD_PATH]. If use_dependencies == true, then
# # Dependencies.load_paths will also be included.
# def load_path_targets
#   if use_dependencies 
#     [$LOAD_PATH, Dependencies.load_paths]
#   else 
#     [$LOAD_PATH]
#   end
# end
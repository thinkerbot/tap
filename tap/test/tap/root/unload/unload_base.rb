require File.expand_path(File.dirname(__FILE__) + "/full_path.rb")
require File.dirname(__FILE__) + "/../unload/nested/relative_path.rb"

# these will be loaded when the nested directory is on the load path
require "nested_load"
require "nested_with_ext.rb"

module UnloadBase
end
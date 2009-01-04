autoload(:YAML, 'yaml')                   # expensive to load

lib = File.expand_path(File.dirname(__FILE__))
$:.unshift(lib) unless $:.include?(lib)

require 'rubygems'
require 'configurable'
require 'tap/constants'

# require in order...
require 'tap/exe'
require 'tap/task'
require 'tap/file_task'
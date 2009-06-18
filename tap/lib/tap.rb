lib = File.expand_path(File.dirname(__FILE__))
$:.unshift(lib) unless $:.include?(lib)

require 'tap/version'
require 'tap/exe'
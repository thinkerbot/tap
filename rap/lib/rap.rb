require 'tap'
require 'rap/declarations'
require 'rap/version'

module Rap
  autoload(:Rake, 'rap/rake')
  RAP_HOME = File.expand_path("#{File.dirname(__FILE__)}/..")
end
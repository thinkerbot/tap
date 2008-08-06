$:.unshift File.join(File.dirname(__FILE__), '../lib')

# runs all subsets (see Tap::Test::SubsetMethods)
ENV["ALL"] = "true"
Dir.glob("./**/*_test.rb").each {|test| require test}
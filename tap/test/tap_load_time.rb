# = Description
# A load time profiler script, useful for identifying requires
# that slow down the loading of a script.
#
# Oftentimes we use but don't always need what we require in
# scripts. This can dramatically slow load times, which can be
# annoying. Use this script to identify slow-loading parts of
# a script and then consider using autoloading to defer
# the require until you really need it.
#
# #require 'stringio'
# autoload(:StringIO, 'stringio')
#
# = Usage
#
# Simply cut-n-paste this script before your first require
# statements (or add the requires at the end of this script):
#
# [profile_load_time.rb ]
# # ... this script ...
#
# require 'time'
#
# Then from the command line:
#
# % ruby profile_load_time.rb
# ================================================================================
# Require/Load Profile (time in ms)
# * Load times > 0.5 ms
# - duplicate requires
# ================================================================================
# * 9.1: time
# * 5.2: parsedate
# * 5.0: date/format
# * 1.2: rational
#
# Total time: 9.105 ms
#
# = Info
# Developer:: Simon Chiang (http://bahuvrihi.wordpress.com)
# License:: MIT-Style (http://en.wikipedia.org/wiki/MIT_License)
# Gist:: http://gist.github.com/5732
 
class RecursiveProfile
  class << self
    def instance
      @@instance
    end
    
    def [](key)
      @@variables[key]
    end
    
    def []=(key, value)
      @@variables[key] = value
    end
  end
  
  attr_reader :results
 
  def initialize
    @results = []
  end
  
  def profile
    current = @results
    @results = []
    
    start = Time.now
    target = [yield]
    target << Time.now-start
    target << @results
    
    @results = current
    @results << target
  end
  
  def each
    recurse(@results, 0) do |value, time, nesting_depth|
      yield(value, time, nesting_depth)
    end
  end
  
  private
 
  def recurse(parent, nesting_depth, &block)
    parent.each do |value, time, children|
      yield(value, time, nesting_depth)
      recurse(children, nesting_depth + 1, &block)
    end
  end
  
  @@instance = RecursiveProfile.new
  @@variables = {}
end
 
def require(path)
  RecursiveProfile.instance.profile do
    begin
      super
      path
    rescue(Exception)
      "#{path} (error: #{$!.message})"
    end
  end
end
 
def load(path)
  RecursiveProfile.instance.profile("#{path} (error)") do
    begin
      super
      path
    rescue(Exception)
      "#{path} (error: #{$!.message})"
    end
  end
end
 
at_exit do
  total_time = (Time.now - RecursiveProfile[:start]) * 10**3
  
  values = []
  duplicates = []
  RecursiveProfile.instance.each do |value, time, nesting_depth|
    (values.include?(value) ? duplicates : values) << value
  end
  
  puts "=" * 80
  puts "Require/Load Profile (time in ms)"
  puts "* Load time > #{RecursiveProfile[:cutoff_in_ms]} ms"
  puts "- Duplicate require"
  puts "=" * 80
  RecursiveProfile.instance.each do |value, time, nesting_depth|
    time_in_ms = time * 10**3
    flags = (time_in_ms > RecursiveProfile[:cutoff_in_ms] ? '*' : ' ')
    
    flags = "-" if duplicates.include?(value) && !values.include?(value)
    values.delete(value)
 
    puts "#{flags} #{' ' * nesting_depth}#{"%.1f" % time_in_ms}: #{value}"
  end
 
  puts
  puts "Total time: #{total_time} ms"
end
 
RecursiveProfile[:cutoff_in_ms] = 0.5
RecursiveProfile[:start] = Time.now
 
###############################################################################
# add requires here
###############################################################################

$:.unshift File.expand_path("#{File.dirname(__FILE__)}/../lib")
$:.unshift File.expand_path("#{File.dirname(__FILE__)}/../../lazydoc/lib")
$:.unshift File.expand_path("#{File.dirname(__FILE__)}/../../configurable/lib")
require 'tap'
require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/support/super_optparse'

class SuperOptionParserTest < Test::Unit::TestCase
  include Tap::Support
  include Tap::Test::SubsetMethods
  
  def test_super_arg_determination_algorithms
    benchmark_test do |x|
      arg = "-arg-"
      long_arg = "-" + "super_long_arg" * 100 + "-"
      n = 100000
      
      x.report("1M regexp") do
        n.times { arg =~ /^-(\w|-\w+)-$/ } 
      end
      
      x.report("1M regexp long") do
        n.times { long_arg =~ /^-(\w|-\w+)-$/ } 
      end
      
      x.report("1M []") do
        n.times { arg[-1] == ?- && arg.length > 2 && arg[0] == ?- }
      end
      
      x.report("1M [] long") do 
        n.times { long_arg[-1] == ?- && long_arg.length > 2 && long_arg[0] == ?- }
      end
    end
  end

end
# Checks the speed of autoload vs require
# (basically asserts that they are the same)

require 'test/unit'
require 'benchmark'

class AutoloadCheck < Test::Unit::TestCase
  include Benchmark

  def test_autoload_vs_require
    bm(20) do |x|
      
      x.report("1M require") do 
        require 'erb'
        1000000.times { ERB }
      end
      
      x.report("1M autoload") do 
        autoload(:StringScanner, 'strscan')
        1000000.times { StringScanner }
      end
      
      x.report("10x require") do 
        10.times do 
          system(%Q{ruby -e "require 'strscan'; StringScanner "})
        end
      end
      
      x.report("10x autoload") do 
        10.times do 
          system(%Q{ruby -e "autoload(:StringScanner, 'strscan'); StringScanner "})
        end
      end
      
    end
  end
end
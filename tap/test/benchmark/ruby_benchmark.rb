require 'tap/test/unit'

class RubyBenchmark < Test::Unit::TestCase
  acts_as_subset_test
  
  def test_launch_times
    benchmark_test(20) do |x|
      n = 10
      
      echo = `which echo`.chomp
      x.report("echo") { n.times { `#{echo}` } }

      ruby = `which ruby`.chomp
      cmd = "#{ruby} -e ''"
      x.report("ruby") { n.times { `#{cmd}` } }
      
      cmd = "#{ruby} -I../lazydoc/lib -rlazydoc -e ''"
      x.report("ruby -rlazydoc") { n.times { `#{cmd}` } }
      
      cmd = "#{ruby} -I../lazydoc/lib -I../configurable/lib -rconfigurable -e ''"
      x.report("ruby -rconfigurable") { n.times { `#{cmd}` } }
      
      cmd = "#{ruby} -I../lazydoc/lib -I../configurable/lib -Ilib -rtap -e ''"
      x.report("ruby -rtap") { n.times { `#{cmd}` } }
      
      cmd = "#{ruby} -ryaml -e ''"
      x.report("ruby -ryaml") { n.times { `#{cmd}` } }
      
      cmd = "#{ruby} -rstrscan -e ''"
      x.report("ruby -rstrscan") { n.times { `#{cmd}` } }
      
      cmd = "#{ruby} -rfileutils -e ''"
      x.report("ruby -rfileutils") { n.times { `#{cmd}` } }
      
      cmd = "#{ruby} -rubygems -e ''"
      x.report("ruby -rubygems") { n.times { `#{cmd}` } }
      
      cmd = "#{ruby} -rrbconfig -e ''"
      x.report("ruby -rrrbconfig") { n.times { `#{cmd}` } }
      
      tap = `which tap`.chomp
      x.report("tap (installed)") { n.times { `#{tap}` } }
      
      x.report("./tap") { n.times { `./tap` } }
      x.report("./tap (rubygems)") { n.times { `#{ruby} -rrubygems -e 'load "tap"'` } }
    end
  end
end
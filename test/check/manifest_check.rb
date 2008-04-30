require 'test/unit'
require 'benchmark'
require 'strscan'
require 'rubygems'

class ManifestTest < Test::Unit::TestCase
  include Benchmark
  
  
  GLOB = File.dirname(__FILE__) + "/../../**/*.rb"
  FILES = Dir.glob( GLOB )[0...100]

  def test_speed_to_scan_files
    bm(20) do |x|
      x.report("100x glob speed") { 100.times { Dir.glob(GLOB) } }
      
      x.report("100x read speed") do
        100.times do
          FILES.each do |path| 
            File.read(path)
          end
        end
      end
      
      x.report("100x scan speed") do
        100.times do
          FILES.each do |path| 
            s = StringScanner.new File.read(path)
            s.scan(/:task:/)
          end
        end
      end
      
      gem_files = []
      x.report("glob all gems") do
        Gem.path.collect do |path|
          gem_files.concat Dir.glob( path + "/**/*.rb" )
        end
      end
      
      x.report("scan #{gem_files.length}") do
        s = StringScanner.new ""
        gem_files.each do |path| 
          s.string = File.read(path)
          s.scan(/:task:/)
        end
      end
    end
  end
end
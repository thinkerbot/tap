require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/schema'
require 'yaml'

class ParserBenchmark < Test::Unit::TestCase
  Parser = Tap::Schema::Parser
  
  #
  # benchmark test
  #
  
  def test_match_speed
    benchmark_test(20) do |x|
      
      str = ".join[1,2,3][4,5,6]is"
      
      r = /\A(?:.(?:\w*[\w:]*))?\[(?:[\d,]*)\]\[(?:[\d,]*)\](?:[A-z]*)\z/
      x.report("without back reference") {100000.times { str =~ r } }
      
      r = /\A(.(\w*[\w:]*))?\[([\d,]*)\]\[([\d,]*)\]([A-z]*)\z/
      x.report("with back reference") {100000.times { str =~ r } }
    end
  end
   
  def test_parse_speed
    benchmark_test(20) do |x|
      
      # 10 nodes
      nodes = Array.new(10) {|i| [i.to_s]}
      str = nodes.collect {|args| "-- #{args.join(' ')}"}.join(" ")
      argv = Shellwords.shellwords(str)
      
      assert_nodes_equal nodes, Parser.new(argv)
      x.report("1000x10 nodes") {1000.times { Parser.new(argv) } }
      
      nodes = Array.new(10) {|i| [i.to_s] + %w{a b c d e}}
      str = nodes.collect {|args| "-- #{args.join(' ')}"}.join(" ")
      argv = Shellwords.shellwords(str)
      
      assert_nodes_equal nodes, Parser.new(argv)
      x.report("1000x10 nodes+5args") {1000.times { Parser.new(argv) } }
      
      ### 100 nodes
      nodes = Array.new(100) {|i| [i.to_s]}
      str = nodes.collect {|args| "-- #{args.join(' ')}"}.join(" ")
      argv = Shellwords.shellwords(str)
      
      assert_nodes_equal nodes, Parser.new(argv)
      x.report("100x100 nodes") {100.times { Parser.new(argv) } }
      
      nodes = Array.new(100) {|i| [i.to_s] + %w{a b c d e}}
      str = nodes.collect {|args| "-- #{args.join(' ')}"}.join(" ")
      argv = Shellwords.shellwords(str)
      
      assert_nodes_equal nodes, Parser.new(argv)
      x.report("100x100 nodes+5arg") {100.times { Parser.new(argv) } }
    end
  end
end
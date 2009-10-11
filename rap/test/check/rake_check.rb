# tests aspects of the rake task declaration
# syntax

require 'test/unit'
require 'rubygems'
require 'rake'

Dir.chdir __FILE__.chomp('.rb')

Rake.application.options.silent = true
class RakeCheck < Test::Unit::TestCase

  def setup
    ARGV.clear
  end
  
  def test_rake_dependency_declaration_syntax
    runlist = []
    
    a = task(:a) {|t| runlist << t }
    b = task(:b => [:a])  {|t| runlist << t }
    c = task(:c => :b)  {|t| runlist << t }
    
    ARGV << 'c'
    Rake.application.run
    assert_equal [a,b,c], runlist
  end
  
  def test_rake_args_declaration
    arg_hash = nil
    x = task(:x, :one, :two, :three) do |t, args|
      arg_hash = args.to_hash
    end
    
    ARGV << 'x[1,2,3]'
    Rake.application.run
    assert_equal({:one => '1', :two => '2', :three => '3'}, arg_hash)
  end
  
  # Rake 0.8.1
  # def test_rake_args_declaration_with_too_few_args_uses_nil
  #   arg_hash = nil
  #   y = task(:y, :one, :two, :three) do |t, args|
  #     arg_hash = args.to_hash
  #   end
  #   
  #   ARGV << 'y[1,2]'
  #   Rake.application.run
  #   assert_equal({:one => '1', :two => '2', :three => nil}, arg_hash)
  # end
  
  # Rake 0.8.3
  def test_rake_args_declaration_with_too_few_args_uses_nil
    arg_hash = nil
    y = task(:y, :one, :two, :three) do |t, args|
      args.one
      args.two
      args.three
      arg_hash = args.to_hash
    end
    
    ARGV << 'y[1,2]'
    Rake.application.run
    assert_equal({:one => '1', :two => '2'}, arg_hash)
  end
  
  def test_rake_args_declaration_with_too_many_args_ignores_extra_args
    arg_hash = nil
    z = task(:z, :one, :two, :three) do |t, args|
      arg_hash = args.to_hash
    end
    
    ARGV << 'z[1,2,3,4]'
    Rake.application.run
    assert_equal({:one => '1', :two => '2', :three => '3'}, arg_hash)
  end
    
  def test_rake_args_declaration_will_override_with_later_args
    arg_hash_a = nil
    s = task(:s, :one, :two, :three) do |t, args|
      arg_hash_a = args.to_hash
    end
    
    arg_hash_b = nil
    s1 = task(:s, :four, :five) do |t, args|
      arg_hash_b = args.to_hash
    end

    ARGV << 's[1,2,3,4,5]'
    Rake.application.run
    assert_equal s, s1
    assert_equal({:four => '1', :five => '2'}, arg_hash_a)
    assert_equal({:four => '1', :five => '2'}, arg_hash_b)
  end
  
  def test_rake_task_declarations_with_namespace
    str = ""
    task(:p) { str << 'a' }

    namespace :p do
      task(:q) { str << 'b' }
    end

    c = task(:r => [:p, 'p:q'])
    task(:r) { str << 'c' }
    task(:r) { str << '!' }
    
    ARGV << 'r'
    Rake.application.run
    assert_equal "abc!", str
  end
  
  def test_namespaces_are_a_bit_crazy
    arr = []
    task(:outer1) { arr << 'outer1' }
    task(:outer2) { arr << 'outer2' }
    
    namespace :nest do
      task(:inner1 => :outer1) { arr << 'inner1' }
      
      # outer2 defined in nest
      task(:inner2 => :outer2) { arr << 'inner2' }
      task(:outer2) { arr << 'inner3' }
    end
    
    ARGV << 'nest:inner1' << 'nest:inner2'
    Rake.application.run
    assert_equal ["outer1", "inner1", "inner3", "inner2"], arr
  end
end

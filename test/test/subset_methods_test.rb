require File.join(File.dirname(__FILE__), '../tap_test_helper.rb') 
require 'tap/test/subset_methods'

class SubsetMethodsTest < Test::Unit::TestCase
  include Tap::Test::SubsetMethods
  include Benchmark
  
  def setup
    @env_hold = {}
    ENV.each_pair do |key, value|
      @env_hold[key] = value
    end
    ENV.clear
  end
  
  def teardown
    ENV.clear
    @env_hold.each_pair do |key, value|
      ENV[key] = value
    end
  end
  
  #
  # env_true test
  #
  
  def test_env_true_is_true_if_var_is_true
    assert !ENV['type']
    assert !env_true?('type')
    
    ENV['type'] = "false"
    assert !env_true?('type')
    
    ENV['type'] = "true"
    assert env_true?('type')
    
    ENV['type'] = "True"
    assert env_true?('type')
    
    ENV['type'] = "TRUE"
    assert env_true?('type')
  end
  
  #
  # extended_test test
  #
  
  def test_extended_test_runs_only_if_extended_true
    was_in_test = false
    extended_test { was_in_test = true }
    assert !was_in_test
    
    ENV['EXTENDED'] = 'true'
    extended_test { was_in_test = true }
    assert was_in_test
  end
  
  #
  # condition test
  #
  
  condition(:is_true) {true}
  condition(:is_false) {false}
  
  def test_conditional_test_runs_only_if_all_conditions_are_true
    test_ran = false
    condition_test(:is_true) { test_ran = true}
    assert test_ran
    
    test_ran = false
    condition_test(:is_false) { test_ran = true}
    assert !test_ran
    
    test_ran = false
    condition_test(:is_true, :is_false) { test_ran = true}
    assert !test_ran
  end
  
  #
  # benchmark_test test
  #
  
  # TODO - find a way to test this is a quiet fashion
  
  #
  # run subset test
  #
  
  def test_run_subset_true_if_ENV_type_is_true
    assert_equal false, run_subset?('type')
    
    ENV['type'] = "true"
    assert_equal true, run_subset?('type')
  end

  def test_run_subset_true_if_ENV_all_is_true
    ENV['ALL'] = "true"
    assert_equal true, run_subset?('type')
  end

  #
  # match_regexp test
  #
  
  def test_match_regexp
    ENV['type'] = "one.*"
    assert_equal true, match_regexp?('type', "one")
    assert_equal true, match_regexp?('type', "one_two")
    assert_equal true, match_regexp?('type', "two_one")
    assert_equal false, match_regexp?('type', "non")
  end

  def test_match_regexp_returns_true_if_ENV_all_true
    ENV['ALL'] = "true"
    assert_equal true, match_regexp?('type', "str", "default")
  end

  def test_match_regexp_returns_default_unless_ENV_type_is_set
    assert_equal "default", match_regexp?('type', "str", "default")
  end
end

class SkippedTest < Test::Unit::TestCase
  include Tap::Test::SubsetMethods
  
  if !conditions.empty?
    raise "conditions were NOT empty in subclass"
  end
  
  condition(:unsatisfied) do 
    false
  end
  
  unless satisfied?(:unsatisfied)
    skip_test
  end
  
  def test_method
    flunk "test WAS run"
  end
end

class SkippedSubTest < SkippedTest
  if conditions.empty?
    raise "conditions WERE empty in subclass"
  end
  
  condition(:unsatisfied) do 
    true
  end

  def test_method
    assert true
  end
end

class NonSkippedTest < Test::Unit::TestCase
  include Tap::Test::SubsetMethods
  
  condition(:unsatisfied) do 
    true    
  end
  
  unless satisfied?(:unsatisfied)
    skip_test
  end
  
  def test_method
    assert true
  end
end
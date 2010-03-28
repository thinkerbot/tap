require File.expand_path('../../../tap_test_helper.rb', __FILE__) 
require 'tap/test/subset_test'

class SubsetTestTest < Test::Unit::TestCase
  include Tap::Test::SubsetTest

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
  # subset_test test
  #
  
  def test_subset_test_normally_does_not_run
    was_in_block = false
    subset_test('type') do 
      was_in_block = true
    end
    
    assert_equal false, was_in_block
  end
  
  def test_subset_test_runs_if_ENV_TYPE_is_true
    ENV['TYPE'] = "true"
    
    was_in_block = false
    subset_test('type') do 
      was_in_block = true
    end
    
    assert_equal true, was_in_block
  end
  
  def test_subset_test_runs_if_ENV_ALL_is_true
    ENV['ALL'] = "true"
    
    was_in_block = false
    subset_test('type') do 
      was_in_block = true
    end
    
    assert_equal true, was_in_block
  end
  
  def test_subset_test_runs_if_ENV_TYPE_TEST_matches_current_test
    ENV['TYPE_TEST'] = "ENV_TYPE_TEST_matches"
    
    was_in_block = false
    subset_test('type') do 
      was_in_block = true
    end
    
    assert_equal true, was_in_block
  end
  
  def test_subset_test_does_not_run_if_ENV_TYPE_TEST_does_not_match_current_test
    
    ENV['TYPE_TEST'] = "run_subset_true_if_ENV_type_test_matches_current"
    was_in_block = false
    subset_test('type') do 
      was_in_block = true
    end
    
    assert_equal false, was_in_block
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
    assert_equal true, match_regexp?('type', "str")
  end

  def test_match_regexp_returns_default_unless_ENV_type_is_set
    assert_equal false, match_regexp?('type', "str", false)
  end
end

#
# inheritance test
#

class SubsetBaseTest < Test::Unit::TestCase
  include Tap::Test::SubsetTest

  if !conditions.empty?
    raise "conditions were NOT empty in subset class"
  end
  
  condition(:satisfied) do 
    true
  end
  
  def test_class_level_condition
    assert self.class.satisfied?(:satisfied)
  end
end

class SubsetInheritanceTest < SubsetBaseTest
  if conditions.empty?
    raise "conditions WERE empty in subclass"
  end
  
  def test_class_level_condition
    assert self.class.satisfied?(:satisfied)
  end
end

class SubsetOverrideTest < SubsetBaseTest
  if conditions.empty?
    raise "conditions WERE empty in subclass"
  end
  
  condition(:satisfied) do 
    false
  end

  def test_class_level_condition
    assert !self.class.satisfied?(:satisfied)
  end
end


require File.join(File.dirname(__FILE__), '../../tap_spec_helper')

module ClearEnv
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
end

describe "SubsetTest.env_true?" do
  include Tap::Test::SubsetTest
  include ClearEnv

  it "must return true when ENV[type] is a string matching true" do
    ENV['type'] = "true"
    env_true?('type').must_equal true

    ENV['type'] = "True"
    env_true?('type').must_equal true

    ENV['type'] = "TRUE"
    env_true?('type').must_equal true
  end
  
  it "must return false when ENV[type] does not match true" do
    ENV['type'].must_equal nil
    env_true?('type').must_equal false

    ENV['type'] = "false"
    env_true?('type').must_equal false
  end
end

describe "SubsetTest.extended_test" do
  include Tap::Test::SubsetTest
  include ClearEnv
  
  it "must run if ENV['EXTENDED'] is true" do
    ENV['EXTENDED'] = 'true'
    was_in_test = false
    extended_test { was_in_test = true }
    was_in_test.must_equal true
  end
  
  it "must not run if ENV['EXTENDED'] is not true" do   
    was_in_test = false
    extended_test { was_in_test = true }
    was_in_test.must_equal false
  end
end

describe "SubsetTest.condition_test" do
  include Tap::Test::SubsetTest
  include ClearEnv
  
  condition(:is_true) {true}
  condition(:is_false) {false}
  
  it "must run if all conditions are true" do
    test_ran = false
    condition_test(:is_true) { test_ran = true}
    test_ran.must_equal true
  end
  
  it "must not run if not all conditions are true" do
    test_ran = false
    condition_test(:is_false) { test_ran = true}
    test_ran.must_equal false
  
    test_ran = false
    condition_test(:is_true, :is_false) { test_ran = true}
    test_ran.must_equal false
  end
end

describe "SubsetTest.run_subset" do
  include Tap::Test::SubsetTest
  include ClearEnv
  
  it "must be true if ENV[type] is true" do
    ENV['type'].must_equal nil
    run_subset?('type').must_equal false
  
    ENV['type'] = "true"
    run_subset?('type').must_equal true
  end
  
  it "must be true if ENV['ALL'] is true" do
    ENV['ALL'] = "true"
    run_subset?('type').must_equal true
  end
end

describe "SubsetTest.match_regexp?" do
  include Tap::Test::SubsetTest
  include ClearEnv
  
  it "must equal true when the input matches ENV[type] as a regexp" do
    ENV['type'] = "one.*"
    match_regexp?('type', "one").must_equal true
    match_regexp?('type', "one_two").must_equal true
    match_regexp?('type', "two_one").must_equal true
    match_regexp?('type', "non").must_equal false
  end
  
  it "must return the default value when the input doesn't match" do
    match_regexp?('type', "str").must_equal true
    match_regexp?('type', "str", false).must_equal false
  end
  
  it "must return true when ENV['ALL'] is true" do
    ENV['type'].must_equal nil
    match_regexp?('type', "str", false).must_equal false
    
    ENV['ALL'] = "true"
    match_regexp?('type', "str", false).must_equal true
  end
end
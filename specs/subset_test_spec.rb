require 'tap/spec'

describe "SubsetTest in Rspec" do
  acts_as_subset_test

  before do
    @env_hold = {}
    ENV.each_pair do |key, value|
      @env_hold[key] = value
    end
    ENV.clear
  end
  
  after do
    ENV.clear
    @env_hold.each_pair do |key, value|
      ENV[key] = value
    end
  end
  
  #
  # env_true? spec
  #
  
  it "should have env_true? return true only when ENV[type] is a string matching true" do
    ENV['type'].must_equal nil
    env_true?('type').must_equal false

    ENV['type'] = "false"
    env_true?('type').must_equal false

    ENV['type'] = "true"
    env_true?('type').must_equal true

    ENV['type'] = "True"
    env_true?('type').must_equal true

    ENV['type'] = "TRUE"
    env_true?('type').must_equal true
  end
  
  #
  # extended_test spec
  #
  
  it "should only run extended_test if ENV['EXTENDED'] is true" do
    was_in_test = false
    extended_test { was_in_test = true }
    was_in_test.must_equal false
        
    ENV['EXTENDED'] = 'true'
    extended_test { was_in_test = true }
    was_in_test.must_equal true
  end
  
  #
  # condition_test spec
  #
  
  condition(:is_true) {true}
  condition(:is_false) {false}
  
  it "should only run condition_test if all conditions are true" do
    test_ran = false
    condition_test(:is_true) { test_ran = true}
    test_ran.must_equal true
  
    test_ran = false
    condition_test(:is_false) { test_ran = true}
    test_ran.must_equal false
  
    test_ran = false
    condition_test(:is_true, :is_false) { test_ran = true}
    test_ran.must_equal false
  end
  
  #
  # run_subset spec
  #
  
  it "should have run_subset run if ENV[type] is true" do
    ENV['type'].must_equal nil
    run_subset?('type').must_equal false
  
    ENV['type'] = "true"
    run_subset?('type').must_equal true
  end
  
  it "should have run_subset run if ENV['ALL'] is true" do
    ENV['ALL'] = "true"
    run_subset?('type').must_equal true
  end
  
  #
  # match_regexp? spec
  #
  
  it "should have match_regexp? equal true when ENV[type] as regexp matches the input" do
    ENV['type'] = "one.*"
    match_regexp?('type', "one").must_equal true
    match_regexp?('type', "one_two").must_equal true
    match_regexp?('type', "two_one").must_equal true
    match_regexp?('type', "non").must_equal false
  end
  
  it "should have match_regexp? return the default value when it doesn't match" do
    match_regexp?('type', "str").must_equal true
    match_regexp?('type', "str", false).must_equal false
  end
  
  it "should have match_regexp? equal true when ENV['ALL'] is true" do
    ENV['type'].must_equal nil
    match_regexp?('type', "str", false).must_equal false
    
    ENV['ALL'] = "true"
    match_regexp?('type', "str", false).must_equal true
  end

end
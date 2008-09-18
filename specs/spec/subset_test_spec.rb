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
  
  describe "env_true?(type)" do
    it "should return true only when ENV[type] is a string matching true" do
      ENV['type'].should be_nil
      env_true?('type').should be_false

      ENV['type'] = "false"
      env_true?('type').should be_false

      ENV['type'] = "true"
      env_true?('type').should be_true

      ENV['type'] = "True"
      env_true?('type').should be_true

      ENV['type'] = "TRUE"
      env_true?('type').should be_true
    end
  end
  
  describe("extended_test") do
    it "should only run if ENV['EXTENDED'] is true" do
      was_in_test = false
      extended_test { was_in_test = true }
      was_in_test.should be_false
          
      ENV['EXTENDED'] = 'true'
      extended_test { was_in_test = true }
      was_in_test.should be_true
    end
  end

  describe("condition_test") do
    condition(:is_true) {true}
    condition(:is_false) {false}
    
    it "should only run if all conditions are true" do
      test_ran = false
      condition_test(:is_true) { test_ran = true}
      test_ran.should be_true

      test_ran = false
      condition_test(:is_false) { test_ran = true}
      test_ran.should be_false

      test_ran = false
      condition_test(:is_true, :is_false) { test_ran = true}
      test_ran.should be_false
    end
  end
  
  describe("run_subset") do
    it "should run if ENV[type] is true" do
      ENV['type'].should be_nil
      run_subset?('type').should be_false

      ENV['type'] = "true"
      run_subset?('type').should be_true
    end
    
    it "should run if ENV['ALL'] is true" do
      ENV['ALL'] = "true"
      run_subset?('type').should be_true
    end
  end
  
  describe("match_regexp?") do
    it "should be true when ENV[type] as regexp matches the input" do
      ENV['type'] = "one.*"
      match_regexp?('type', "one").should be_true
      match_regexp?('type', "one_two").should be_true
      match_regexp?('type', "two_one").should be_true
      match_regexp?('type', "non").should be_false
    end
    
    it "should be return the default value when it doesn't match" do
      match_regexp?('type', "str").should be_true
      match_regexp?('type', "str", false).should be_false
    end
    
    it "should be true when ENV['ALL'] is true" do
      ENV['type'].should be_nil
      match_regexp?('type', "str", false).should be_false
      
      ENV['ALL'] = "true"
      match_regexp?('type', "str", false).should be_true
    end
  end

end
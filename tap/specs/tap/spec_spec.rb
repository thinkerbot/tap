require File.join(File.dirname(__FILE__), '../tap_spec_helper')

describe "Tap::Spec" do
  acts_as_file_test(
    :root => "some/root/dir", 
    :relative_paths => {
      :input => 'input', 
      :output => 'output', 
      :expected => 'expected'},
    :absolute_paths => {:path => File.expand_path('/to/file')})
    
  it "should have the acts_as_file_spec root directory" do
    ctr[:root].must_equal File.expand_path("some/root/dir")
  end
  
  it "should have the specified relative_paths" do
    ctr.relative_paths.must_equal(:input => 'input', :output => 'output', :expected => 'expected')
  end
  
  it "should have the specified absolute_paths" do
    ctr.absolute_paths.must_equal(:path => File.expand_path('/to/file'))
  end
end

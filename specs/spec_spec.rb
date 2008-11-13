require 'tap/spec'

describe "Tap::Spec" do
  acts_as_file_test :root => "some/root/dir"
  
  it "should have the acts_as_file_spec root directory" do
    ctr[:root].must_equal File.expand_path("some/root/dir")
  end
  
  it "should have the default :input, :output, :expected directories" do
    ctr.directories.must_equal(:input => 'input', :output => 'output', :expected => 'expected')
  end
end

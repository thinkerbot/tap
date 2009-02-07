require File.join(File.dirname(__FILE__), '../tap_spec_helper')

describe "Spec.acts_as_file_test" do
  acts_as_file_test(
    :root => "some/root/dir", 
    :relative_paths => {
      :input => 'input', 
      :output => 'output', 
      :expected => 'expected'},
    :absolute_paths => {:path => File.expand_path('/to/file')})
    
  it "must setup the specified class test root" do
    ctr[:root].must_equal File.expand_path("some/root/dir")
    ctr.relative_paths.must_equal(:input => 'input', :output => 'output', :expected => 'expected')
    ctr.absolute_paths.must_equal(:path => File.expand_path('/to/file'))
  end
end

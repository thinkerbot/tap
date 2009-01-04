$:.unshift File.dirname(__FILE__) + '/../lib'

ENV["ALL"] = 'true'
Dir.glob(File.dirname(__FILE__) + "/**/*_test.rb").each do |test| 
  next if test =~ /test\/check/
  require test
end
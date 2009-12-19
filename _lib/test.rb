require 'tap/task'

# :startdoc::task run gh-page tests
class Test < Tap::Task
  def process
    files = Dir.glob("_test/**/*_test.rb").collect {|path| "'#{path}'"}
    system("ruby -rubygems -e 'ARGV.each{|f| load f}' #{files.join(', ')}")
  end
end 

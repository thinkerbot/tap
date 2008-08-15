require 'tap'

# Check::manifest 'Run checks.'
class Check < Tap::FileTask
  def process(pattern="")
    Dir.glob( File.join('test',  "**/*#{pattern}*_check.rb") ).each do |check_file|
      puts "=" * 80
      puts Tap::Support::CommandLine.usage(check_file)
      puts "=" * 80
      sh "ruby -w '#{check_file}'"
    end
  end
end
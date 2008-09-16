require 'tap'

# Note to self:
# Check will not be picked up by 'ruby bin/tap -T'
# since the search paths for tap_root are pre-set
# by Tap::Exe.

# Check::manifest run checks
class Check < Tap::FileTask
  def process(pattern="")
    Dir.glob( File.join('test',  "**/*#{pattern}*_check.rb") ).each do |check_file|
      puts "=" * 80
      puts Tap::Support::Lazydoc.usage(check_file)
      puts "=" * 80
      sh "ruby -w '#{check_file}'"
    end
  end
end
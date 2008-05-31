# tap console {options}
#
# Opens up an IRB session with Tap initialized to the configurations 
# in tap.yml. Access the Tap::App.instance through 'app'.

#
# handle options
#

OptionParser.new do |opts|
  opts.separator ""
  opts.separator "options:"

  opts.on("-h", "--help", "Show this message") do
    opts.banner = Tap::Support::TDoc.usage(__FILE__)
    puts opts
    exit
  end
end.parse!(ARGV)

require "irb"

def app
  Tap::App.instance
end

def env
  Tap::Env.instance
end

IRB.start
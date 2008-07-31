# tap manifest
#
# Prints information about each env.
#

OptionParser.new do |opts|
  
  opts.separator ""
  opts.separator "options:"

  opts.on("-h", "--help", "Show this message") do
    opts.banner = cmdline.usage(__FILE__)
    puts opts
    exit
  end
  
end.parse!(ARGV)

def collect_map(env, name)
  width = 10
  map = env.map(name).collect do |(key, path)|
    path = case path
    when Tap::Support::Constant then path.require_path
    else path
    end
    
    width = key.length if width < key.length
    [key, env.root.relative_filepath(:root, path) || path]
  end.collect do |args|
    "%-#{width}s (%s)" % args
  end
  
  map.unshift("") unless map.empty?
  map
end

ARGV.collect! {|arg| Regexp.new(arg)}
Tap::Env.instance.map(:envs).collect do |(key, env)|
  next unless ARGV.empty? || ARGV.find do |regexp| 
    key =~ regexp
  end
  
  [key, env]
end.compact.each do |(key, env)|
  puts %Q{#{'-' * 80}
%s (%s)
  commands     #{collect_map(env, :commands).join("\n    ")}
  tasks        #{collect_map(env, :tasks).join("\n    ")}
  generators   #{collect_map(env, :generators).join("\n    ")}

} % [key + ':', env.root.root]
end
# tap manifest
#
# Prints information about each env.
#

options = {}
OptionParser.new do |opts|
  
  opts.separator ""
  opts.separator "options:"

  opts.on("-h", "--help", "Show this message") do
    opts.banner = cmdline.usage(__FILE__)
    puts opts
    exit
  end
  
  opts.on("-e", "--envs_only", "Only list environments") do
    options[:envs_only] = true
  end
  
  opts.on("-r", "--require FILEPATH", "Require the specified file") do |value|
    require value
  end
  
end.parse!(ARGV)

# Simply a method to collect and format paths for
# the specified manifest.
def collect_map(env, manifest)
  width = 10
  map = manifest.minimize.collect do |(key, path)|
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

# Collect remaining args as 
env = Tap::Env.instance
envs_manifest = if ARGV.empty?
  env.manifest(:envs, true).minimize
else
  ARGV.collect do |name| 
    entry = env.find(:envs, name, false)
    raise "could not find an env matching: #{name}" if entry == nil
    entry
  end
end

width = 10
envs_manifest.each {|(env_name, e)| width = env_name.length if width < env_name.length}
width += 2

env.each do |current|
  env_name, current = envs_manifest.find {|(env_name, e)| e == current }
  next if env_name == nil
  
  puts '-' * 80 unless options[:envs_only]
  puts "%-#{width}s (%s)" % [env_name + ':', current.root.root]
  
  next if options[:envs_only]
  
  manifest_keys = (Tap::Env.manifests.keys + current.manifests.keys).uniq 
  manifest_keys.each do |name|
    next if name == :envs
    manifest = current.manifest(name, true)
    next if manifest.empty?
    
    puts "  %-10s %s" % [name, collect_map(current, manifest).join("\n    ")]
  end
end

if ARGV.empty?
  puts '-' * 80
  puts
  env.recursive_each(0, nil) do |current, nesting_depth, last_env|
    env_name, current = envs_manifest.find {|(env_name, e)| e == current }

    leader = nesting_depth == 0 ? "" : '|   ' * (nesting_depth - 1) + (last_env == current ? "`- " : "|- ")
    puts("#{leader}#{env_name}")
    [nesting_depth + 1, current.envs[-1]]
  end
  puts
end
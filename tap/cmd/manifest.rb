# usage: tap manifest [options]
#
# Prints a manifest of all resources in the current tap environment.

options = {}
ConfigParser.new do |opts|
  
  opts.separator ""
  opts.separator "options:"

  opts.on("-h", "--help", "Show this message") do
    puts Lazydoc.usage(__FILE__)
    puts opts
    exit
  end
  
  # opts.on("-t", "--tree", "Just print the env tree.") do
  #   options[:tree] = true
  # end
  
  # opts.on("-r", "--require FILEPATH", "Require the specified file") do |value|
  #   require value
  # end
  
end.parse!(ARGV)

env = Tap::Exe.instance
env_keys = env.minihash(true)

filter = case
when ARGV.empty? then env_keys.keys
else
  ARGV.collect do |name| 
    env.minimatch(name) or raise "could not find an env matching: #{name}"
  end
end

template = %Q{<% unless manifests.empty? %>
#{'-' * 80}
<%= (env_key + ':').ljust(width) %> (<%= env.path %>)
<% manifests.each do |manifest_key, entries| %>
  <%= manifest_key %>
<%   entries.each do |key, value| %>
    <%= key.ljust(width-4) %> (<%= value %>)
<%   end %>
<% end %>
<% end %>
}

# build and collect manifests by (env, manifest_key)
envs = {}
[:commands, :tasks].each do |manifest_key|
  manifest = env.send(manifest_key)
  manifest.build_all
  next if manifest.empty?
  
  manifest.cache.each_pair do |key, value|
    next unless key.kind_of?(Tap::Env)
    manifests = (envs[key] ||= {})
    manifests[manifest_key] = value
  end
end

summary = env.inspect(template, :width => 10) do |templater, globals|
  current = templater.env
  manifests = []
  templater.manifests = manifests
  next unless filter.include?(current)
  
  width = globals[:width]
  env_key = env_keys[current]
  templater.env_key = env_key
  width = env_key.length if width < env_key.length
  
  envs[current].each_pair do |manifest_key, manifest|
    entries = manifest.minimap.collect do |key, entry|
      path = case entry
      when Tap::Env::Constant
        entry.require_path
      else
        entry
      end
  
      width = key.length if width < key.length
      [key, current.root.relative_path(:root, path) || path]
    end
    
    manifests << [manifest_key, entries]
  end if envs.has_key?(current)
  
  globals[:width] = width
end
puts summary

if ARGV.empty?
  templaters = []
  globals = env.recursive_inject([0, nil]) do |(nesting_depth, last), current|
    leader = nesting_depth == 0 ? "" : '|   ' * (nesting_depth - 1) + (last == current ? "`- " : "|- ")
    templaters << Tap::Support::Templater.new("<%= leader %><%= env_key %> \n", 
      :env_key => env_keys[current],
      :leader => leader
    )
    
    [nesting_depth + 1, current.envs[-1]]
  end

  tree = templaters.collect do |templater|
    templater.build
  end.join

  puts '-' * 80
  puts
  puts tree
  puts
end
# usage: tap manifest [options] [filter]
#
# Prints a manifest of all resources in the current tap environment.  Env
# keys may be provided to select a specific set of environments to list.
#
#   % tap manifest
#   % tap manifest tap-tasks
#
options = {}
ConfigParser.new do |opts|
  
  opts.separator ""
  opts.separator "options:"

  opts.on("-h", "--help", "Show this message") do
    puts Lazydoc.usage(__FILE__)
    puts opts
    exit
  end
end.parse!(ARGV)

template = %Q{<% unless manifests.empty? %>
#{'-' * 80}
<%= (env_key + ':').ljust(width) %> (<%= env.root.root %>)
<% manifests.each do |type, entries| %>
  <%= type %>
<%   entries.each do |key, value| %>
    <%= key.ljust(width-4) %> (<%= value %>)
<%   end %>
<% end %>
<% end %>
}

# filter envs to manifest
env = Tap::Env.instance
env_keys = env.minihash(true)
filter = if ARGV.empty?
  env_keys.keys
else
  ARGV.collect do |name| 
    env.minimatch(name) or raise "could not find an env matching: #{name}"
  end
end

# build the summary
summary = env.inspect(template, :width => 10) do |templater, globals|
  current = templater.env
  manifests = []
  templater.manifests = manifests
  next unless filter.include?(current)
  
  # determine the width of the keys
  width = globals[:width]
  env_key = env_keys[current]
  templater.env_key = env_key
  width = env_key.length if width < env_key.length
  
  # build up the entries for each type of resource
  current.registry(true).to_a.sort_by do |(type, entries)|
    type.to_s
  end.each do |type, entries|
    next if entries.empty?
    
    entries.extend(Tap::Env::Minimap)
    entries = entries.minimap.collect do |key, entry|
      path = if entry.kind_of?(Tap::Env::Constant)
        entry.require_path
      else
        entry
      end
  
      width = key.length if width < key.length
      [key, current.root.relative_path(:root, path) || path]
    end
    
    manifests << [type, entries]
  end
  
  globals[:width] = width
end
puts summary

if ARGV.empty?
  templaters = []
  visited = []
  globals = env.recursive_inject([nil, nil]) do |(leader, last), current|
    current_leader = if leader
      leader.to_s + (last == current ? "`- " : "|- ")
    else
      ""
    end
    
    templaters << Tap::Templater.new("<%= leader %><%= env_key %> \n", 
      :env_key => env_keys[current],
      :leader => current_leader
    )
    
    if leader
      leader += (last == current ? '    ' : '|   ')
    else
      leader = ""
    end
    
    visited << current
    current.envs.reverse_each do |e|
      unless visited.include?(e)
        last = e
        break
      end
    end
    
    [leader, last]
  end

  tree = templaters.collect do |templater|
    templater.build
  end.join

  puts '-' * 80
  puts
  puts tree
  puts
end
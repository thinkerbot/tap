# tap manifest
#
# Prints information about the current tap environment.
#

options = {}
OptionParser.new do |opts|
  
  opts.separator ""
  opts.separator "options:"

  opts.on("-h", "--help", "Show this message") do
    opts.banner = Tap::Support::Lazydoc.usage(__FILE__)
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

env = Tap::Env.instance
env_names = {}
env.manifest(:envs, true).minimize.each do |name, environment|
  env_names[environment] = name
end

filter = case
when ARGV.empty? then env_names.keys
else
  ARGV.collect do |name| 
    unless entry = env.find(:envs, name, false) 
      raise "could not find an env matching: #{name}"
    end

    entry[1]
  end
end

template = %Q{#{'-' * 80}
<%= (env_name + ':').ljust(width) %> (<%= env.root.root %>)
<% manifests.each do |manifest_name, entries| %>
  <%= manifest_name %>
<%   entries.each do |name, path| %>
    <%= name.ljust(width-4) %> (<%= path %>)
<%   end %>
<% end %>
}

width = 10
summary = env.inspect(template) do |templater, share|
  current = templater.env
  next unless filter.include?(current)
  
  manifest_keys = (Tap::Env.manifests.keys + current.manifests.keys).uniq 
  manifests = manifest_keys.collect do |name|
    next if name == :envs
    
    manifest = current.manifest(name, true)
    next if manifest.empty?
    
    entries = manifest.minimize.collect do |(entry, path)|
      path = case path
      when Tap::Support::Constant then path.require_path
      else path
      end
  
      width = entry.length if width < entry.length
      [entry, current.root.relative_filepath(:root, path) || path]
    end
    
    [name, entries]
  end
  templater.manifests = manifests.compact
  templater.env_name = env_names[current]
  
  width = templater.env_name.length if width < templater.env_name.length
  share[:width] = width + 2
end
puts summary

if ARGV.empty?
  tree = env.recursive_inspect("<%= leader %><%= env_name %> \n", 0, nil) do |templater, share, nesting_depth, last|
    current = templater.env
    
    templater.leader = nesting_depth == 0 ? "" : '|   ' * (nesting_depth - 1) + (last == current ? "`- " : "|- ")
    templater.env_name = env_names[current]
    
    [nesting_depth + 1, current.envs[-1]]
  end
  
  puts '-' * 80
  puts
  puts tree
  puts
end
# tap signal sig pid
#

opts = ConfigParser.new(:file => false, :preview => false)

opts.on("-p", "--preview", "preview the signal") do
  opts[:preview] = true
end

opts.on("-f", "--file FILE", "pid is read from the file") do |input|
  opts[:file] = input
end

opts.on("-l", "--list", "list available signals") do
  Signal.list.to_a.sort_by {|(sig, n)| n }.each do |(sig, n)|
    puts "  #{sig}: #{n}"
  end
  exit
end

# add option to print help
opts.on("-h", "--help", "Show this message") do
  puts Lazydoc.usage(__FILE__)
  puts opts
  exit
end

signal, pid, *args = opts.parse!(ARGV)

signal = signal =~ /\A\d+\z/ ? signal.to_i : signal.upcase
unless Signal.list.any? {|(sig, n)| signal == sig || signal == n }
  puts "unknown or unsupported signal: #{signal}"
  exit
end

if opts[:file]
  unless File.exists?(opts[:file])
    puts "pid file does not exist: #{opts[:file]}"
    exit
  end
  
  pid = File.read(opts[:file])
end

unless args.empty?
  warn "ignoring: #{args.inspect}"
end

if opts[:preview]
  puts "preview: #{signal} #{pid}"
else
  puts "signal: #{signal} #{pid}"
  Process.kill(signal, pid.to_i)
  FileUtils.rm(opts[:file]) if opts[:file]
end

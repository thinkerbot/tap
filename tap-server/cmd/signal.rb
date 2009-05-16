# tap signal sig pid
#

opts = ConfigParser.new(:file => false, :preview => false)

opts.on("-p", "--preview", "preview the signal") do
  opts.config[:preview] = true
end

opts.on("-f", "--file", "pid is read from the file") do
  opts.config[:file] = true
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

if opts.config[:file]
  unless File.exists?(pid)
    puts "pid file does not exist: #{pid}"
    exit
  end
  
  pid = File.read(pid)
end

unless args.empty?
  warn "ignoring: #{args.inspect}"
end

if opts.config[:preview]
  puts "preview: #{signal} #{pid}"
else
  Process.kill(signal, pid.to_i)
end

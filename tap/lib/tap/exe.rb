require 'tap/env'
require 'tap/task'
require 'tap/schema'

module Tap
  module Exe
    
    # Adapted from Gem.find_home
    def self.user_home
      ['HOME', 'USERPROFILE'].each do |homekey|
        return ENV[homekey] if ENV[homekey]
      end

      if ENV['HOMEDRIVE'] && ENV['HOMEPATH'] then
        return "#{ENV['HOMEDRIVE']}#{ENV['HOMEPATH']}"
      end

      begin
        File.expand_path("~")
      rescue
        File::ALT_SEPARATOR ? "C:/" : "/"
      end
    end

    # Setup an execution environment.
    def self.setup(dir=Dir.pwd, argv=ARGV)
      if argv[-1] == '-d-'
        argv.pop
        $DEBUG = true 
      end
      
      # load global configurations
      path = File.join(dir, CONFIG_FILE)
      user = Env.load_config(path)
      global = Env.load_config(GLOBAL_CONFIG_FILE)
      config = {
        :root => dir,
        :gems => :all
      }.merge(global).merge(user)
      
      # instantiate
      @instance = Env.new(config, CONFIG_FILE).extend Exe
      
      # add the tap env if necessary
      unless @instance.instances.has_key?(File.join(TAP_HOME))
        @instance.push Env.new(TAP_HOME) 
      end
      
      @instance
    end
    
    def self.instance
      @instance
    end
    
    def self.extended(exe)
      exe.app = Tap::App.new
    end
    
    # The config file path
    CONFIG_FILE = "tap.yml"
    
    # The home directory for Tap
    TAP_HOME = File.expand_path("#{File.dirname(__FILE__)}/../..")
    
    # The global home directory
    GLOBAL_HOME = File.join(user_home, ".tap")
    
    # The global config file path
    GLOBAL_CONFIG_FILE = File.join(GLOBAL_HOME, CONFIG_FILE)
    
    attr_accessor :app
    
    def commands
      @commands ||= manifest do |env|
        env.glob_config(:cmd_paths, "**/*.rb", :cmd)
      end
    end
    
    def tasks
      @tasks ||= constant_manifest('manifest') do |env|
        env.glob_config(:lib_paths, "**/*.rb", :lib) do |dir, path|
          [dir, path]
        end
      end
    end
    
    def run(argv=ARGV)
      command = argv.shift.to_s
      
      case command  
      when '', '--help'
        yield
      else
        if path = commands.seek(command)
          load path # run the command, if it exists
        else
          puts "Unknown command: '#{command}'"
          puts "Type 'tap --help' for usage information."
        end
      end
    end
    
    def build(schema) 
      schema.build do |type, argh|
        
        
        if type == :join
          instantiate_join(argh)
        else
          instantiate_task(argh, app)
        end
      end
    end
    
    def instantiate_join(metadata)
      # Temporary!
      case metadata
      when Array
        metadata = metadata.dup
        metadata.shift # remove id that would normally look up join class
        
        join_class = Support::Join
        join_class.parse!(metadata)
      when Hash
        join_class = Support::Join
        join_class.instantiate(metadata)
      when nil
        Support::Join.new
      end
    end
    
    def instantiate_task(metadata, app)
      case metadata
      when Array
        metadata = metadata.dup
        tasc(metadata.shift).parse!(metadata, app)
      when Hash
        tasc(metadata[:id]).instantiate(metadata, app)
      end
    end
    
    def tasc(id)
      const = tasks.search(id) or raise ArgumentError, "unknown task: #{id}"
      const.constantize
    end
    
    def set_signals(app)
      # info signal -- Note: some systems do 
      # not support the INFO signal 
      # (windows, fedora, at least)
      signals = Signal.list.keys
      Signal.trap("INFO") do
        puts app.info
      end if signals.include?("INFO")

      # interuption signal
      Signal.trap("INT") do
        puts " interrupted!"
        # prompt for decision
        while true
          print "stop, terminate, exit, or resume? (s/t/e/r):"
          case gets.strip
          when /s(top)?/i 
            app.stop
            break
          when /t(erminate)?/i 
            app.terminate
            break
          when /e(xit)?/i 
            exit
          when /r(esume)?/i 
            break
          else
            puts "unexpected response..."
          end
        end
      end if signals.include?("INT")
    end
    
    TEMPLATES = {}
    
    TEMPLATES[:tasks] = %Q{<% if count > 1 %>
<%= env_name %>:
<% end %>
<% entries.each do |name, const| %>
<%   desc = const.document[const.name]['manifest'] %>
  <%= name.ljust(width) %><%= desc.empty? ? '' : '  # ' %><%= desc %>
<% end %>}

    TEMPLATES[:generators] = %Q{<% if count > 1 %>
<%= env_name %>:
<% end %>
<% entries.each do |name, const| %>
<%   desc = const.document[const.name]['generator'] %>
  <%= name.ljust(width) %><%= desc.empty? ? '' : '  # ' %><%= desc %>
<% end %>}

  end
end
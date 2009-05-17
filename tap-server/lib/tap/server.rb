require 'rack'
# require 'tap'
# require 'tap/server/data'
require 'tap'
require 'tap/server/server_error'

module Tap
  class Server
    class << self
      
      def parse(argv=ARGV)
        parse!(argv.dup)
      end
      
      # Same as parse, but removes arguments destructively.
      def parse!(argv=ARGV)
        opts = ConfigParser.new(:config_file => nil)
        
        unless configurations.empty?
          opts.separator "configurations:"
          opts.add(configurations)
          opts.separator ""
        end
        
        opts.separator "options:"
        
        # add option to specify a config file
        opts.on('--config FILE', 'Specifies a config file') do |value|
          opts[:config_file] = value
        end
        
        yield(opts) if block_given?
        
        # parse! (note defaults are not added because in
        # instantiate the instance is reconfigured rather
        # than initialized with the configs)
        argv = opts.parse!(argv, :add_defaults => false)
        
        config = opts.nested_config
        config_file = opts.delete(:config_file)
        
        instance = if config_file
          new(load_config(config_file)).reconfigure(config)
        else
          new(config)
        end
        
        [instance, argv]
      end
    end
    
    include Rack::Utils
    include Configurable
    
    config :servers, %w[thin mongrel webrick], {    # the preferred server handlers
      :long => :server
    }, &c.list 
    
    config :host, 'localhost', &c.string            # the server host
    config :port, 8080, &c.integer_or_nil           # the server port
    
    # Server implements a secret for HTTP administration of the server (ex
    # remote shutdown). Under many circumstances this functionality is
    # undesirable; specify a nil secret, the default, to prevent remote
    # administration.
    config :secret, nil, &c.string_or_nil           # the admin secret
    
    config :daemonize, false, &c.flag
    
    nest :root, Root, :type => :hidden
    
    attr_reader :handler
    
    def initialize(config={})
      @handler = nil
      initialize_config(config)
    end
    
    def uri
      "http://#{host}:#{port}"
    end
    
    # Returns true if input is equal to the secret, if a secret is set. Used
    # to test if a particular request has rights to a remote administrative
    # action.
    def admin?(input)
      secret != nil && input == secret
    end
    
    def daemonize!
      if File.exists?(root['pid'])
        raise "pid file already exists: #{root['pid']}"
      end
      
      fork and exit
      Process.setsid
      fork and exit
      Dir.chdir "/"
      File.umask 0000
      STDIN.reopen  "/dev/null"
      STDOUT.reopen root.prepare('stdout'), "a"
      STDERR.reopen root.prepare('stderr'), "a"
      
      root.prepare('pid') {|io| io << Process.pid }
      root.prepare('uri') {|io| io << uri }
      root.prepare('secret') {|io| io << secret } if secret
    end
    
    def cleanup!
      %w{pid uri secret}.each do |path|
        path = root[path]
        FileUtils.rm(path) if File.exists?(path)
      end unless running?
    end
    
    def running?
      @handler != nil
    end
    
    # Runs self as configured, on the specified server, host, and port.  Use an
    # INT signal to interrupt.
    def run!(rack_app, handler=rack_handler)
      return self if running?
      
      daemonize! if daemonize
      handler.run(rack_app, :Host => host, :Port => port) do |handler_instance|
        @handler = handler_instance
        trap(:INT) { stop! }
        yield if block_given?
      end
      
      self
    end

    # Stops the server if running (ie a handler is set).
    def stop!
      if running?
        # Use thins' hard #stop! if available, otherwise just #stop
        @handler.respond_to?(:stop!) ? @handler.stop! : @handler.stop
        @handler = nil
        
        cleanup! if daemonize
        yield if block_given?
      end
      
      self
    end

    protected

    # Looks up and returns the first available Rack::Handler as listed in the
    # servers configuration. (Note rack_handler returns a handler class, not
    # an instance).  Adapted from Sinatra.detect_rack_handler
    def rack_handler # :nodoc:
      servers.each do |server_name|
        begin
          return Rack::Handler.get(server_name)
        rescue LoadError
        rescue NameError
        end
      end
      raise "Server handler (#{servers.join(',')}) not found."
    end
  end
end
require 'rack'
require 'tap/server/data'
require 'tap/server/server_error'

module Tap
  
  # ::configurable
  class Server
    class << self
      
      def parse(argv=ARGV)
        parse!(argv.dup)
      end
      
      # Same as parse, but removes arguments destructively.
      def parse!(argv=ARGV)
        opts = ConfigParser.new
        
        unless configurations.empty?
          opts.separator "configurations:"
          opts.add(configurations)
          opts.separator ""
        end
        
        opts.separator "options:"
        
        # add option to specify a config file
        opts.on('--config FILE', 'Specifies a config file') do |config_file|
          opts.config.merge!(load_config(config_file))
        end
        
        yield(opts) if block_given?
        
        # parse! (note defaults are not added because in
        # instantiate the instance is reconfigured rather
        # than initialized with the configs)
        argv = opts.parse!(argv, :add_defaults => false)
        
        [new(opts.nested_config), argv]
      end
      
      protected
      
      # Recursively loads path into a nested configuration file.
      def load_config(path)
        # optimization to check for trivial paths
        return {} if Root::Utils.trivial?(path)
        
        Configurable::Utils.load_file(path, true) do |base, key, value|
          base[key] ||= value if base.kind_of?(Hash)
        end
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
    
    attr_reader :handler
    
    def initialize(config={})
      @handler = nil
      initialize_config(config)
    end
    
    def uri(path=nil)
      "http://#{host}:#{port}#{path ? '/' : ''}#{path}"
    end
    
    # Returns true if input is equal to the secret, if a secret is set. Used
    # to test if a particular request has rights to a remote administrative
    # action.
    def admin?(input)
      secret != nil && input == secret
    end
    
    def running?
      @handler != nil
    end
    
    # Runs self as configured, on the specified server, host, and port.  Use an
    # INT signal to interrupt.
    def run!(rack_app, handler=rack_handler)
      return self if running?
      
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
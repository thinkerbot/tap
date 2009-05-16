module Tap
  module Runner
    include Configurable
    
    config :servers, %w[thin mongrel webrick], {    # a list of preferred handlers
      :long => :server
    }, &c.list 

    config :host, 'localhost', &c.string            # the server host
    config :port, 8080, &c.integer_or_nil           # the server port
    config :server_root, nil, &c.string_or_nil
    
    attr_reader :handler
    
    def initialize(*args)
      @handler = nil
      super
    end
    
    def server_file(path)
      server_root ? File.join(server_root, path.to_s) : nil
    end
    
    def uri
      "http://#{host}:#{port}"
    end
    
    def rooted?
      server_root && File.exists?(server_file(:pid)) && File.exists?(server_file(:uri))
    end
    
    # Runs self as configured, on the specified server, host, and port.  Use an
    # INT signal to interrupt.
    def run!(handler=rack_handler)
      if server_root
        raise "a server is already daemonized to: #{server_root}" if rooted?
        
        FileUtils.mkdir_p(server_root) unless File.exists?(server_root)

        File.open(server_file(:pid), 'w') {|io| io << Process.pid }
        File.open(server_file(:uri), 'w') {|io| io << uri }

        @stdio = [$stdin, $stdout, $stderr]
        $stdout = File.open(server_file(:stdout), "a")
        $stderr = File.open(server_file(:stderr), "a")
      end
      
      handler.run self, :Host => host, :Port => port do |handler_instance|
        @handler = handler_instance
        trap(:INT) { stop! }
        yield if block_given?
      end
      
      self
    end

    # Stops the server if running (ie a handler is set).
    def stop!
      if @handler
        # Use thins' hard #stop! if available, otherwise just #stop
        @handler.respond_to?(:stop!) ? @handler.stop! : @handler.stop
        @handler = nil
        
        if rooted?
          $stdout.close
          $stderr.close
          $stdin, $stdout, $stderr = @stdio
          
          FileUtils.rm(server_file(:pid))
          FileUtils.rm(server_file(:uri))
        end
        
        yield if block_given?
      end
      
      self
    end

    def kill!
      if rooted?
        pid = File.read(server_path(:pid)).to_i
        if pid == 0
          $stderr.puts "== Sending KILL to #{pid}"
          Process.kill('KILL', pid)
        end
      end
      
      raise "Failure to kill! (no pid is available for: #{server_root.inspect})"
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
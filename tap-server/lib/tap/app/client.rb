require 'net/http'
require 'thread'

module Tap
  class App
    
    #   require 'lib/tap/app/client'
    # 
    #   client = Tap::App::Client.connect!('127.0.0.1', 8080)
    #   puts client.kill_server!
    #
    class Client
      class << self
        
        def connect(host='127.0.0.1', port=8080, options={})
          begin
            return new(host, port, options)
          rescue(ConnectionError)
            nil
          end
        end
        
        def connect!(host='127.0.0.1', port=8080, options={})
          # attempt to connect to an existing server
          if client = connect(host, port, options)
            return client
          end
          
          options = {
            :cmd => "tap app",
            :timeout => 10,
            :log => $stderr
          }.merge(options)
          
          secret = options[:secret]
          log = options[:log]
          
          # launch a new server subprocess
          cmd = "#{options[:cmd]} --host #{host} --port #{port}" + (secret ? " --secret #{secret}" : "")
          thread = Thread.new do
            log << "+ #{host}:#{port}/#{secret} (#{Thread.current.object_id})\n" if log
            system(cmd)
            log << "- #{host}:#{port} (#{$?.exitstatus})\n" if log
          end
          
          # try connecting as long as the timeout specifies
          (options[:timeout].to_i * 10).times do
            sleep(0.1)
            
            # if the connection is successful, store the signature on
            # the thread so that it may be retreived for kill_server!
            if client = connect(host, port, options)
              thread[:server] = client.pid
              return client
            end
          end

          raise "could not determine pid for server subprocess: #{cmd}"
        end
        
        # Returns an array of living threads that have a server running on them.
        # The pid of the server is accessible through the thread local variable
        # :server.  For example:
        #
        #   pids = Client.server_threads.collect {|thread| thread[:server]}
        #
        def server_threads
          Thread.list.select {|thread| thread[:server] != nil }
        end
        
        # Stops all servers launched by Client.connect!  Servers are stopped in
        # the same manner as described by the kill_server! method.  It's a good
        # idea to ensure this method gets called in the event of errors, in
        # order to protect against zombie processes.  One way to do so is via
        # at_exit:
        #
        #   at_exit do
        #     Tap::App::Client.kill_servers!
        #   end
        #
        def kill_servers!(join=true)
          threads = []
          Thread.list.each do |thread|
            if pid = thread[:server]
              Process.kill("KILL", pid)
              threads << thread
            end
          end
          
          threads.each {|thread| thread.join } if join
          
          true
        end
      end
      
      include Configurable
      
      # The server host (that self connects to)
      config :host, '127.0.0.1'
      
      # The server port (that self connects to)
      config :port, 8080
      
      # The server secret, used to acquire the pid of the server
      config :secret, nil
      
      # The pid of the server, or 0 if no pid can be acquired
      attr_reader :pid
      
      # A log device (only requires << as an api)
      attr_reader :log

      def initialize(host, port, options={})
        @host = host
        @port = port
        @secret = options[:secret]
        @log = options[:log] || $stderr

        begin
          @pid = Net::HTTP.get(host, "/pid/#{secret}", port).to_i
        rescue(Errno::ECONNREFUSED)
          raise ConnectionError.new(self, "could not reach server")        
        rescue(Errno::EPIPE) # EPIPE for JRuby
          raise ConnectionError.new(self, "could not reach server")
        end
      end
      
      # Terminates the server if:
      # * a pid was obtained (ie the client knows the server secret)
      # * a server thread is associated with this pid
      #
      # Termination occurs by sending the pid process a KILL signal.  This
      # method will wait on the server thread if join is true.  Returns
      # true if the sever was stopped, and false otherwise.
      def kill_server!(join=true)
        # no pid was obtained
        return false if pid == 0

        # find the thread running the server for self
        unless thread = Thread.list.find {|t| t[:server] == pid }
          return false
        end
        
        log << "! #{host}:#{port} (#{thread.object_id})\n" if log
        Process.kill("KILL", pid)
        thread.join if join
        
        true
      end

      class ConnectionError < StandardError
        def initialize(client, message)
          super("#{message}: #{client.host}:#{client.port}")
        end
      end
    end
  end
end
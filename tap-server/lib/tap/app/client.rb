require 'net/http'
require 'thread'

module Tap
  class App
    
    #   require 'lib/tap/app/client'
    # 
    #   client = Tap::App::Client.connect!('127.0.0.1', 8080)
    #   puts client.stop_server!
    #
    class Client
      class << self
        
        def connect(host='127.0.0.1', port=8080, options={})
          begin
            return new(host, port, options[:secret])
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
            :timeout => 10
          }.merge(options)
          secret = options[:secret]
          
          # launch a new server subprocess
          cmd = "#{options[:cmd]} --host #{host} --port #{port}" + (secret ? "--secret #{secret}" : "")
          thread = Thread.new do
            $stderr.puts "+ #{host}:#{port}/#{secret} (#{Thread.current.object_id})"
            system(cmd)
            $stderr.puts "- #{host}:#{port} (#{$?.exitstatus})"
          end
          
          # try connecting as long as the timeout specifies
          (options[:timeout].to_i * 10).times do
            sleep(0.1)
            
            # if the connection is successful, store the signature on
            # the thread so that it may be retreived for stop_server!
            if client = connect(host, port, options)
              thread[:client] = client.pid
              return client
            end
          end

          raise "could not determine pid for server subprocess: #{cmd}"
        end
        
        #
        #   at_exit do
        #     Tap::App::Client.stop_servers!
        #   end
        #
        def stop_servers!(join=true)
          threads = []
          Thread.list.each do |thread|
            if pid = thread[:client]
              Process.kill("INT", pid)
              threads << thread
            end
          end
          
          threads.each {|thread| thread.join } if join
          
          true
        end
      end
      
      attr_reader :host
      attr_reader :port
      attr_reader :secret
      attr_reader :pid

      def initialize(host, port, secret=nil)
        @host = host
        @port = port
        @secret = secret

        begin
          @pid = Net::HTTP.get(host, "/pid/#{secret}", port).to_i
        rescue(Errno::ECONNREFUSED)
          raise ConnectionError.new(self, "could not reach server")
        end
      end
      
      def signature
        [host, port]
      end
      
      def stop_server!
        # no pid was obtained
        return false if pid == 0

        # find the thread running the server for self
        unless thread = Thread.list.find {|t| t[:client] == pid }
          return false
        end
        
        $stderr.puts "! #{host}:#{port} (#{thread.object_id})"
        Process.kill("INT", pid)
        thread.join if thread
        
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
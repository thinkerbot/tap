require 'tap'

module Tap
  class App
    module Server
      
      attr_reader :env
      attr_reader :app
      
      def initialize(env=Tap::Env.new, app=Tap::App.new)
        @env = env
        @app = app
      end
      
      def post_init
        puts "-- someone connected to the echo server!"
      end

      def receive_data data
        send_data ">>>you sent: #{data}"
        close_connection if data =~ /quit/i
      end

      def unbind
        puts "-- someone disconnected from the echo server!"
      end
    end
  end
end
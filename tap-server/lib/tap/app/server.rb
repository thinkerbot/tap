require 'tap'

module Tap
  class App
    module Server
      
      attr_reader :env
      attr_reader :app
      
      def initialize(env=Tap::Env.new, app=Tap::App.new)
        @env = env.extend(Tap::Exe)
        @app = app
      end
      
      def receive_data(data)
        schema = Tap::Schema.parse(data)
        begin
          env.build(schema, app).each do |queue|
            app.queue.concat(queue)
          end
                    
          app.run
        rescue
          puts $!.message
          puts $!.backtrace
        end
      end
    end
  end
end
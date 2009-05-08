require 'tap/app'
require 'tap/server/persistence'

module Tap
  class Server
    class Session
      CONFIG_FILE = 'session.yml'
      
      def initialize(attributes={})
        self.attributes = {
          :app => nil,
          :persistence => {}
        }.merge(attributes)
      end
    
      def id
        persistence.id
      end
    
      def attributes
        { :id => id,
          :app => app == Tap::App.instance ? nil : app.config.to_hash,
          :persistence => persistence.config.to_hash
        }
      end
    
      def attributes=(input)
        input.each_pair do |key, value|
          case key
          when :id
          when :app
            self.app = value
          when :persistence
            self.persistence = value
          else
            raise "unknown attribute: #{key.inspect}"
          end
        end
      end
    
      def save
        persistence.open(:root, CONFIG_FILE) do |io|
          io << YAML.dump(attributes)
        end
        self
      end
    
      def destroy
        self
      end
    
      ###
    
      attr_reader :persistence
      
      def persistence=(input)
        @persistence = case input
        when Persistence then input
        when Hash        then Persistence.new(input)
        else raise "cannot convert to Persistence: #{input.inspect}"
        end
      end
      
      attr_reader :app
      
      def app=(input)
        @app = case input
        when Tap::App then input
        when Hash     then Tap::App.new(input)
        when nil      then Tap::App.instance
        else raise "cannot convert to Tap::App: #{input.inspect}"
        end
      end
    end
  end
end
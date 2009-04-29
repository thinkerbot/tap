require 'tap/app'
require 'tap/server/persistence'

module Tap
  class Server
    class Session
      def initialize(attributes={})
        self.attributes = {
          :app => {},
          :persistence => {}
        }.merge(attributes)
      end
    
      def id
        persistence.id
      end
    
      def attributes
        { :id => id,
          :app => app.config,
          :persistence => persistence.config
        }
      end
    
      def attributes=(input)
        input.each_pair do |key, value|
          case key
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
        FileUtils.mkdir_p(persistence.root)
        self
      end
    
      def destroy
        self
      end
    
      ###
    
      attr_reader :persistence
      
      def persistence=(input)
        @persistence = cast(input, Persistence)
      end
      
      attr_reader :app
      
      def app=(input)
        @app = cast(input, Tap::App)
      end
      
      protected
      
      def cast(input, klass)
        case input
        when klass then input
        when Hash  then klass.new(input)
        else raise "cannot convert to #{klass}: #{input.inspect}"
        end
      end
    end
  end
end
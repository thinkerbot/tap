module Tap
  class Server
    class Session
      class << self
        def create(attributes) # :yields: obj
        end
      
        def find(id)
        end
      
        def update(id, attributes)
        end
      
        def destroy(id)
        end
      end
    
      def initialize(attributes)
      end
    
      def id
      end
    
      def attributes
        # session.yml
      end
    
      def attributes=(input)
      end
    
      def save
      end
    
      def destroy
      end
    
      ###
    
      def persistence
      end
    
      def app
        # app.log linked to stderr by default
      end
    end
  end
end
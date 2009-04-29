module Tap
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
    
    # => array of schema model instances (SessionFile)
    def schema
    end
    
    # => array of datum model instances (SessionFile)
    def data
    end
    
    def app
      # app.log linked to stderr by default
    end
    
    def log
      # log of $stdout (session log)
    end
    
  end
end
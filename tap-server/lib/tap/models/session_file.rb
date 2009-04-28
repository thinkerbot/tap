module Tap
  module Models
    
    class SessionFile
      class << self
        def create(attributes) # :yields: obj
        end
        
        def read(id)
        end
        
        def update(id, attributes)
        end
        
        def destroy(id)
        end
        
        def exists?(id)
        end
      end
      
      def initialize(attributes)
      end
      
      def id
        # path
      end
      
      def attributes
      end
      
      def attributes=(input)
      end
      
      def save
        # save to disk
      end
      
      def destroy
        # rm
      end
      
      ###
      
      def content
      end
      
      def content=(input)
      end
      
      def open
        # yield io, close if block given
      end
    end
  end
end
require 'configurable'
require 'tap/app/audit'

module Tap
  class App
    module Join
      
      # The App calling self (set by App during execute)
      attr_accessor :app
      
      public
      
      # Interns a new Join by extending the block with Join. 
      def self.intern(&block)
        block.extend self
      end
      
      # Sets up required variables for extended objects.
      def self.extended(obj)
        obj.instance_variable_set(:@app, nil)
      end
    end
  end
end
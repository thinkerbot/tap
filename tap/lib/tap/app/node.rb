module Tap
  class App
    
    # Node adds the node API[link:files/doc/API.html] to objects responding
    # to call.  Additional helper methods are added to simplify the
    # construction of workflows; they are not required by the API.
    module Node

      # The joins called when call completes
      attr_accessor :joins
      
      # Interns a new node by extending the block with Node. 
      def self.intern(&block)
        block.extend self
      end
      
      # Sets up required variables for extended objects.
      def self.extended(obj) # :nodoc:
        obj.instance_variable_set(:@joins, [])
      end
      
      # Sets the block as a join for self.
      def on_complete(&block) # :yields: result
        self.joins << block if block
        self
      end
    end
  end
end

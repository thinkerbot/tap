module Tap
  class App
    
    # Node adds the node API[link:files/doc/API.html] to objects responding
    # to call.  Additional helper methods are added to simplify the
    # construction of workflows; they are not required by the API.
    module Node

      # The join called when call completes
      attr_accessor :join
      
      # An array of node dependencies
      attr_reader :dependencies
      
      # Interns a new node by extending the block with Node. 
      def self.intern(&block)
        block.extend self
      end
      
      # Sets up required variables for extended objects.
      def self.extended(obj) # :nodoc:
        obj.instance_variable_set(:@join, nil)
        obj.instance_variable_set(:@dependencies, [])
      end
      
      # Sets a block as the join for self.
      def on_complete(&block) # :yields: result
        self.join = block
        self
      end
      
      # Adds the dependency to self.  Dependencies are resolved by an app
      # during App#dispatch and must be valid nodes.
      def depends_on(dependency)
        raise "cannot depend on self" if dependency == self
        unless dependencies.include?(dependency)
          dependencies << dependency
        end
        self
      end
    end
  end
end

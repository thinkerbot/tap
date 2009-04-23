module Tap
  class App
    
    # Node wraps objects to make them executable by App.
    #
    # === Node API
    #
    # Tap::App requires Nodes respond to the following methods:
    #
    #   join:: returns an object responding to call(result) or nil
    #   dependencies:: returns an array of dependency nodes
    #
    # Node is designed to add this API to any object responding to call.  Node
    # adds additional methods like on_complete that make nodes easy to work
    # with, but they are not required.
    module Node

      # The join called when call completes
      attr_accessor :join
      
      # An array of Node dependencies
      attr_reader :dependencies
      
      # Interns a new Node by extending the block with Node. 
      def self.intern(&block)
        block.extend self
      end
      
      # Sets up required variables for extended objects.
      def self.extended(obj)
        obj.instance_variable_set(:@join, nil)
        obj.instance_variable_set(:@dependencies, [])
      end
      
      # Sets a block as the join for self.
      def on_complete(&block) # :yields: result
        self.join = block
        self
      end
      
      # Adds the dependency to self.  Dependencies are resolved by an app
      # during App#dispatch and must be valid Nodes.
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
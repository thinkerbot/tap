module Tap
  module Node
    attr_reader :app
    
    # The joins called when call completes
    attr_accessor :joins
    
    # Interns a new node by extending the block with Node. 
    def self.extended(obj)
      obj.joins = []
      obj.app ||= Tap::App.current
    end
    
    def self.intern(app=Tap::App.current, &block)
      block.instance_variable_set(:@app, app)
      block.extend(Node)
      block
    end
    
    def enq(*args)
      app.enq(self, args)
    end
    
    def exe(*inputs)
      app.exe(self, inputs)
    end
    
    # Sets the block as a join for self.
    def on_complete(&block) # :yields: result
      joins << block if block
      self
    end
  end
end

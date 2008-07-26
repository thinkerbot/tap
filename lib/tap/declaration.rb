require File.dirname(__FILE__)

def tasc(name, configs={}, &block)
  Tap::Task.subclass(name, configs, &block)
end
    
def fasc(name, configs={}, &block)
  Tap::FileTask.subclass(name, configs, &block)
end
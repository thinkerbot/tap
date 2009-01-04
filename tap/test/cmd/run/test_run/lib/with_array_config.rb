# ::manifest
class WithArrayConfig < Tap::Task

  config :array, [], &c.array            # an array config
  
  def process
    require 'pp'
    log self.name, PP.singleline_pp(array, '')
  end
  
end
# ::manifest
class WithSwitchConfig < Tap::Task

  config :switch, false, &c.switch            # a switch config
  
  def process
    require 'pp'
    log self.name, PP.singleline_pp(switch, '')
  end
  
end
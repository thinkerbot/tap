# ::manifest
class WithHashConfig < Tap::Task

  config :hc, {}, &c.hash            # a hash config
  
  def process
    require 'pp'
    log self.name, PP.singleline_pp(hc, '')
  end
  
end
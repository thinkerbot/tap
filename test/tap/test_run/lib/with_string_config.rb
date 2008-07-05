class WithStringConfig < Tap::Task

  config :string, '', &c.string            # a string config
  
  def process
    require 'pp'
    log self.name, PP.singleline_pp(string, '')
  end
  
end
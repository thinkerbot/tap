class WithListConfig < Tap::Task

  config :list, [], &c.list            # a list config
  
  def process
    require 'pp'
    log self.name, PP.singleline_pp(list, '')
  end
  
end
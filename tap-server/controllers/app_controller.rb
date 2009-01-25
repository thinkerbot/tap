require 'tap/controller'

class AppController < Tap::Controller
  def index
    render('index.erb')
  end
  
  def reset
    @env.reset
    index
  end
end
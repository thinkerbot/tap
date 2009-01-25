require 'tap/controller'

class AppController < Tap::Controller
  def index
    env.render(:views, 'index.erb')
  end
end
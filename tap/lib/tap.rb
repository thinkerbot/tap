require 'tap/version'
require 'tap/app'
require 'tap/env'

module Tap
  module_function
  def setup(dir=Dir.pwd)
    env = Env.setup(dir)
    App.instance = App.new({}, :env => env)
  end
end
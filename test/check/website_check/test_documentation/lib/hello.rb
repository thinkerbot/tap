# == Description
# Your basic hello world task.
# === Usage
#   % tap run greet NAME
#
class Hello < Tap::Task
  config :greeting, 'hello'           # a greeting string
  
  def process(name)
    log greeting, name
    name
  end
end
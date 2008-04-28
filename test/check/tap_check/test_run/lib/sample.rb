# == Description
# Replace with a description.  The default task simply 
# demonstrates the use of a config and logging.  
# === Usage
# Replace with usage instructions
#
class Sample < Tap::Task
  # use config to set task configurations
  # configs have accessors by default
  
  config :key, 'value'           # a sample config
  
  # process defines what the task does; use the
  # same number of inputs to enque the task
  # as specified here
  def process(input)
    # use log to record information
    result = "#{input} was processed with #{key}"
    log self.name, result
  
    result
  end
  
end
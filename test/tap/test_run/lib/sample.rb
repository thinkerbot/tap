# :manifest: manifest summary
# command line description 
# line one
#
# line two

# Sample documentation
class Sample < Tap::Task

  config :key, 'value'     # a sample config
  
  # :startdoc: :usage: sample one
  def process(input) 
    # use log to record information
    result = "#{input} was processed with #{key}"
    log self.name, result
  
    result
  end
  
end
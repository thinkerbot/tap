# ::manifest manifest summary
# command line description 
# line one
#
# line two
#
#   some = code    # => line1
#   some = code    # => line2
#
# a very very very long line three
# that requires wrapping to 
# display properly.  a very very very 
# long line three that requires 
# wrapping to display properly.

# Sample documentation
class Sample < Tap::Task

  config :key, 'value'     # a sample config
  
  # :startdoc::args one
  def process(input) 
    # use log to record information
    result = "#{input} was processed with #{key}"
    log self.name, result
  
    result
  end
  
end
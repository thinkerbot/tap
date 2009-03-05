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
  
  self.args = "one"
  def process(input) 
  end
end
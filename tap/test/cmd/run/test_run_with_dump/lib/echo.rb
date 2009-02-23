# ::manifest
class Echo < Tap::Task
  def process(*inputs) 
    inputs << name
    inputs.flatten!
    puts inputs.inspect
  
    inputs
  end
end
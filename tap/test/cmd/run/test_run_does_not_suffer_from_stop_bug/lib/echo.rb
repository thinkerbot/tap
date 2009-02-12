# ::manifest
class Echo < Tap::Task
  def process(input) 
    puts input
  end
end
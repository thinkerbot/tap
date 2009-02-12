# ::manifest
class Stop < Tap::Task
  def process
    app.stop
  end
end
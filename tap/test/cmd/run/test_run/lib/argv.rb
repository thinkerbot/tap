# ::manifest
class Argv < Tap::Task
  def process
    log self.name, "was #{ARGV.inspect}"
  end
end
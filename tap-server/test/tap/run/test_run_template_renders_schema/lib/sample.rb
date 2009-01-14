
# ::manifest a sample task
# A long description
class Sample < Tap::Task
  config :key, 'value'
  def process(a, b='B', *c)
  end
end

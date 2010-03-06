require 'tap/task'
require 'tap/generator/destroy'

module Tap
  module Tasks
    # :startdoc::task
    #
    class Destroy < Tap::Task
      def process(generator, *args)
        app.env.constant(generator) do |constant|
          constant.types.has_key?('generator')
        end.parse!(args) do |generator, argv|
          generator.extend Generator::Destroy
          generator.call(argv)
        end
      end
    end 
  end
end

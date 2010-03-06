require 'tap/task'
require 'tap/generator/generate'

module Tap
  module Tasks
    # :startdoc::task
    #
    class Generate < Tap::Task
      def process(*args)
        app.call('sig' => 'build', 'args' => args) do |generator, argv|
          generator.set(Generator::Generate)
          return generator.call(argv)
        end
      end
    end 
  end
end

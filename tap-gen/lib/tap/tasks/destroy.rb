require 'tap/task'
require 'tap/generator/destroy'

module Tap
  module Tasks
    # :startdoc::task
    #
    class Destroy < Tap::Task
      def process(*argv)
        app.call('sig' => 'build', 'args' => args) do |generator, argv|
          generator.set(Generator::Destroy)
          return generator.call(argv)
        end
      end
    end 
  end
end

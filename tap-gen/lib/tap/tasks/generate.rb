require 'tap/task'
require 'tap/generator/generate'

module Tap
  module Tasks
    # :startdoc::task
    #
    class Generate < Tap::Task
      class << self
        def parse!(argv=ARGV, app=Tap::App.current)
          unless argv.empty? || argv[0] == '--help'
            generator = argv.shift
            argv.unshift('--')
            argv.unshift(generator)
            argv.unshift('--generator')
          end
          
          super(argv, app)
        end
      end
      
      config_attr :generator, nil do |generator|
        raise "no generator specified" if generator.nil?
        @generator = app.env.constant(generator) do |constant|
          constant.types.has_key?('generator')
        end
      end
      
      def process(*args)
        generator.parse!(args, app) do |generator, argv|
          generator.extend Generator::Generate
          generator.call(argv)
        end
      end
    end 
  end
end

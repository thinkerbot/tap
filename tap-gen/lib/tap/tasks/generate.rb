require 'tap/task'
require 'tap/generator/generate'

module Tap
  module Tasks
    # :startdoc::task
    #
    class Generate < Tap::Task
      class << self
        def parse!(argv=ARGV, app=Tap::App.instance)
          if argv.empty? || argv[0] == '--help'
            puts "#{self}#{desc.empty? ? '' : ' -- '}#{desc.to_s}"
            puts help
            exit
          end
          
          obj = build({}, app)
          
          if block_given?
            yield(obj, argv)
          else
            Utils.warn_ignored_args(argv)
            obj
          end
        end
      end
      
      def process(generator, *args)
        app.env.constant(generator) do |constant|
          constant.types.has_key?('generator')
        end.parse!(args, app) do |generator, argv|
          generator.extend Generator::Generate
          generator.call(argv)
        end
      end
    end 
  end
end

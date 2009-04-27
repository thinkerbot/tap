require 'tap/generator/base'

module Tap
  module Generator
    module Exe
      
      def generators
        constant_manifest(:generators)
      end
      
      def run(mod, argv=ARGV)
        if argv.empty? || argv == ['--help']
          yield
        end
        
        name = argv.shift
        generator_class = generators[name] or raise "unknown generator: #{name}"
        generator, argv = generator_class.parse(argv)
        generator.extend(mod).process(*argv)
      end
      
    end
  end
end
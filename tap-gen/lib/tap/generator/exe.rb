require 'tap/generator/base'

module Tap
  module Generator
    module Exe
      
      def generators
        constant_manifest(:generator)
      end
      
      def run(mod, argv=ARGV)
        if argv.empty? || argv == ['--help']
          yield
        end
        
        name = argv.shift
        env, const = generators.eeek(name)
        
        unless const
          raise "unknown generator: #{name}"
        end
        
        generator, argv = const.constantize.parse(argv)
        generator.template_dir = env.class_path(:templates, generator) {|dir| File.directory?(dir) }
        generator.extend(mod).process(*argv)
      end
    end
  end
end
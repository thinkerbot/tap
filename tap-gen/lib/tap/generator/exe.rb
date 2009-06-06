require 'tap/generator/base'

module Tap
  module Generator
    
    # Methods used by the generate and destroy commands.
    module Exe
      
      def run(mod, argv=ARGV)
        if argv.empty? || argv == ['--help']
          yield
        end
        
        name = argv.shift
        env, const = eeek('generator', name)
        
        unless const
          raise "unknown generator: #{name}"
        end
        
        generator = const.constantize.parse(argv)
        generator.template_dir = env.class_path(:templates, generator) {|dir| File.directory?(dir) }
        generator.extend(mod).process(*argv)
      end
    end
  end
end
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
        env, const = seek('generator', name, false)
        
        unless const
          raise "unknown generator: #{name}"
        end
        
        generator = const.constantize.parse(argv)
        
        # do not reassign dir unless a templates directory
        # is found, otherwise you get an error
        if dir = env.class_path(:templates, generator) {|dir| File.directory?(dir) }        
          generator.template_dir = dir
        end
        
        generator.extend(mod).process(*argv)
      end
    end
  end
end
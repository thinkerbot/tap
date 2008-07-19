require 'tap/generator/manifest'

module Tap
  module Generator 
    class Base < Tap::FileTask

      config :pretend, false, &c.boolean         # Run but rollback any changes.
      config :force, false, &c.boolean           # Overwrite files that already exist.
      config :skip, false, &c.boolean            # Skip files that already exist.
    
      def process(target_dir, *argv)
        actions = [[:directory, target_dir]]
        manifest(Manifest.new(actions))
        
        iterate(actions) do |action, args, block|
          send(action, *args, &block)
        end
      end
      
      def manifest(m)
      end
      
      def templates_dir
        File.dirname(self.class.source_file) + '/templates'
      end
      
      def log_relative(action, path)
        log(action, app.relative_filepath(Dir.pwd, path))
      end
    
      def iterate(action)
        raise NotImplementedError
      end
    
      def directory(path)
        raise NotImplementedError
      end
    
      def file(path)
        raise NotImplementedError
      end
    end
  end
end
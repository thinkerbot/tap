require 'tap/generator/manifest'

module Tap
  module Generator 
    class Base < Tap::Task

      config :pretend, false, &c.boolean         # Run but rollback any changes.
      config :force, false, &c.boolean           # Overwrite files that already exist.
      config :skip, false, &c.boolean            # Skip files that already exist.
      
      attr_accessor :file_task, :template_dir, :target_dir
      
      def initialize(*args)
        super

        batch.each do |task|
          task.file_task = Tap::FileTask.new(name)
          task.template_dir = File.dirname(self.class.source_file) + '/templates'
        end
      end
      
      def process(target_dir, *argv)
        @target_dir = target_dir
        
        actions = []
        manifest(Manifest.new(actions), *argv)
        
        iterate(actions) do |action, args, block|
          send(action, *args, &block)
        end
        
        @target_dir = nil
        file_task.added_files
      end
      
      def log_relative(action, path)
        log(action, app.relative_filepath(Dir.pwd, path))
      end
      
      def manifest(m, *argv)
        raise NotImplementedError
      end
      
      def iterate(action)
        raise NotImplementedError
      end
    
      def directory(path, options={})
        raise NotImplementedError
      end
    
      def file(path, options={})
        raise NotImplementedError
      end
      
      def directories(paths, options={})
        paths.each do |path|
          directory(path, options)
        end
      end
      
      def template(path, template_path, attributes={}, options={})
        template_path = File.expand_path(template_path, template_dir)
        templater = Support::Templater.new(File.read(template_path), attributes)
        
        file(path, options) do |file| 
          file << templater.build
        end
      end
  
    end
  end
end
require 'tap/generator/manifest'

module Tap
  module Generator 
    class Base < Tap::Task
      Constant = Tap::Support::Constant

      config :pretend, false, &c.flag         # Run but rollback any changes.
      config :force, false, &c.flag           # Overwrite files that already exist.
      config :skip, false, &c.flag            # Skip files that already exist.
      
      attr_accessor :file_task, :template_dir, :target_dir
      
      def initialize(*args)
        super

        batch.each do |task|
          task.file_task = Tap::FileTask.new(name)
          task.template_dir = File.dirname(self.class.source_file) + '/templates'
        end
      end
      
      def process(*argv)
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
    
      def directory(target, options={})
        raise NotImplementedError
      end
    
      def file(target, options={})
        raise NotImplementedError
      end
      
      def directories(targets, options={})
        targets.each do |target|
          directory(target, options)
        end
      end
      
      def template(target, source, attributes={}, options={})
        template_path = File.expand_path(source, template_dir)
        templater = Support::Templater.new(File.read(template_path), attributes)
        
        file(target, options) do |file| 
          file << templater.build
        end
      end
      
      def template_files
        Dir.glob(template_dir + "/**/*").sort.each do |source|
          target = Tap::Root.relative_filepath(template_dir, source)
          yield(source, target)
        end
      end
  
    end
  end
end
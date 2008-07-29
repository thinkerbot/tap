require 'tap/generator/manifest'

module Tap
  module Generator 
    class Base < Tap::Task
      class << self
        def lazydoc(resolve=false, args_method=:manifest)
          super
        end
      end
      
      Constant = Tap::Support::Constant

      config :pretend, false, &c.flag         # Run but rollback any changes.
      config :force, false, &c.flag           # Overwrite files that already exist.
      config :skip, false, &c.flag            # Skip files that already exist.
      
      attr_accessor :file_task, :template_dir, :target_dir
      
      def initialize(config={}, name=nil, app=App.instance)
        super(config, name, app)

        @file_task = Tap::FileTask.new
        @template_dir = File.dirname(self.class.source_file) + '/templates'
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
      
      def directories(root, targets, options={})
        directory(root)
        targets.each do |target|
          directory(File.join(root, target), options)
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
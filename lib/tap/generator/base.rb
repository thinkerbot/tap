require 'tap/generator/manifest'

module Tap
  module Generator
    class Arguments < Lazydoc::Arguments
      def arguments(shift_manifest_arg=true)
        shift_manifest_arg ? @arguments[1..-1] : @arguments
      end
    end
    
    class Base < Tap::Task
      define :file_task, Tap::FileTask
      
      lazy_attr :manifest, 'generator'
      lazy_attr :args, :manifest
      lazy_register :manifest, Arguments
      
      config :pretend, false, &c.flag         # Run but rollback any changes.
      config :force, false, &c.flag           # Overwrite files that already exist.
      config :skip, false, &c.flag            # Skip files that already exist.
      
      # The generator-specific templates directory.  By default:
      # 'path/to/name/templates' for 'path/to/name/name_generator.rb'
      attr_accessor :template_dir
      
      # The IO used to pull prompt inputs.  By default $stdin
      attr_accessor :prompt_in
      
      # The IO used to prompt users for input.  By default $stdout
      attr_accessor :prompt_out
      
      def initialize(*args)
        super
        @prompt_in = $stdin
        @prompt_out = $stdout
        @template_dir = File.dirname(self.class.source_file) + '/templates'
      end
      
      def process(*argv)
        actions = []
        manifest(Manifest.new(actions), *argv)
        
        iterate(actions) do |action, args, block|
          send(action, *args, &block)
        end
        
        file_task.added_files
      end
      
      # Overridden in subclasses to add actions to the input Manifest.
      # Any arguments passed to process will be passed to manifest
      # unchanged.
      def manifest(m, *argv)
        raise NotImplementedError
      end
      
      # Peforms each of the input actions.  Overridden by one of the
      # action mixins (ex Generate or Destory).
      def iterate(actions)
        raise NotImplementedError
      end
      
      # Peforms a directory action (ex generate or destroy).  Must be
      # overridden by one of the action mixins (ex Generate or Destroy).
      def directory(target, options={})
        raise NotImplementedError
      end
    
      # Peforms a file action (ex generate or destroy).  Must be
      # overridden by one of the action mixins (ex Generate or Destroy).
      def file(target, options={})
        raise NotImplementedError
      end
      
      # Makes (or destroys) the root and each of the targets, relative
      # to root.  Options are passed onto directory.
      def directories(root, targets, options={})
        directory(root, options)
        targets.each do |target|
          directory(File.join(root, target), options)
        end
      end
      
      # Makes (or destroys) the target by templating the source using
      # the specified attributes.  Source is expanded relative to
      # template_dir.  Options are passed onto file.
      def template(target, source, attributes={}, options={})
        template_path = File.expand_path(source, template_dir)
        templater = Support::Templater.new(File.read(template_path), attributes)
        
        file(target, options) do |file| 
          file << templater.build
        end
      end
      
      # Yields each source file under template_dir to the block, with
      # a target path of the source relative to template_dir.
      def template_files
        Dir.glob(template_dir + "/**/*").sort.each do |source|
          next unless File.file?(source)
          
          target = Tap::Root.relative_filepath(template_dir, source)
          yield(source, target)
        end
      end
      
      # Logs the action with the relative filepath from Dir.pwd to path.
      def log_relative(action, path)
        log(action, Root.relative_filepath(Dir.pwd, path))
      end
    end
  end
end
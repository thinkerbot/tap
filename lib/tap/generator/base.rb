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
      
      def template(path, template_path, attributes=default_attributes, options={})
        template_path = File.expand_path(template_path, template_dir)
        templater = Support::Templater.new(File.read(template_path), attributes)
        templater.target_path = path
        
        content = templater.build
        nesting = options.delete(:nesting)
        
        file(path, options) do |file| 
          file << nest(nesting, content)
        end
      end
      
      def file_name
        File.basename(target_dir)
      end
      
      def class_name
        file_name.camelize
      end
      
      def const_name
        target_dir.camelize
      end
      
      def const_path
        target_dir
      end
      
      def nesting
        nesting = File.dirname(target_dir).camelize
        nesting == "." ? nil : nesting
      end
      
      def nesting_depth
        nesting ? nesting.count('::') : 0
      end
      
      def default_attributes
        { :file_name => file_name, 
          :class_name => class_name,
          :const_name => const_name, 
          :nesting_depth => nesting_depth, 
          :const_path => const_path
        }
      end
      
      def nest(nesting, content)
        return content if nesting.to_s.empty?
        
        nestings = nesting.split(/::/)
        lines = content.split(/\r?\n/)

        depth = nestings.length
        lines.collect! {|line| "  " * depth + line}

        nestings.reverse_each do |mod_name|
          depth -= 1
          lines.unshift("  " * depth + "module #{mod_name}")
          lines << ("  " * depth + "end")
        end

        lines.join("\n")
      end
    end
  end
end
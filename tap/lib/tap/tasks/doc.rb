require 'tap/task'

module Tap
  module Tasks
    # :startdoc::task <replace with summary>
    class Doc < Tap::Task
      
      def env
        app.env
      end
      
      def doc(const_str, page=nil)
        constant = env.constant(const_str)
        modules = constant.kind_of?(Class) ? constant.ancestors - constant.included_modules : [constant]

        case
        when constant && page
          render(modules, page)
        when constant
          pages(modules)
        else
          "constants:\n#{env.constants.summarize}"
        end
      end
      
      def render(modules, page) # :nodoc:
        constant = modules.last
        path = env.module_path(:doc, modules, "#{page}.erb") {|file| File.exists?(file) }

        unless path
          raise "no such page: #{page.inspect} (#{constant.to_s})"
        end

        Templater.build_file(path, :app => self, :constant => constant)
      end
      
      # Retrieves a path associated with the inheritance hierarchy of an object.
      # An array of modules (which naturally can include classes) are provided
      # and module_path traverses each, forming paths like:
      #
      # path(dir, module_path, *paths)
      #
      # By default 'module_path' is 'module.to_s.underscore' but modules can
      # specify an alternative by providing a module_path method.
      #
      # Paths are yielded to the block until the block returns true, at which
      # point the current the path is returned. If no block is given, the
      # first path is returned. Returns nil if the block never returns true.
      def module_path(dir, modules, *paths, &block)
        paths.compact!
        while current = modules.shift
          module_path = if current.respond_to?(:module_path)
            current.module_path
          else
            current.to_s.underscore
          end

          if path = self.path(dir, module_path, *paths, &block)
            return path
          end
        end

        nil
      end
      
    end 
  end
end
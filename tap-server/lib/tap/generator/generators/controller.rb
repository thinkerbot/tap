require 'tap/generator/generators/resource'

module Tap
  module Generator
    module Generators
      # :startdoc::generator generates a controller
      #
      # Generates a new Tap::Controller and an associated test file.
      class Controller < Resource
        
        def manifest(m, const_name)
          const = super
          
          views_dir = path('views', "#{const.path}")
          m.directory File.dirname(views_dir)
          m.template path(views_dir, "index.erb"), "view.erb"
          
          const
        end
      end 
    end
  end
end

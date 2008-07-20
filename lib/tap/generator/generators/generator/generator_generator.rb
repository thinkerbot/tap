module Tap::Generator::Generators
  class GeneratorGenerator < Tap::Generator::Base

    def manifest(m, const_name)
      const = Constant.new(const_name.camelize)
      
      generator_path = app.filepath('lib', "#{const.path}")
      m.directory generator_path
      m.template File.join(generator_path, const.basename + '.rb'), "task.erb", :const => const
      m.directory File.join(generator_path, const.basename)

      const
    end
  end
end
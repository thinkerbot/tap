require 'tap/generator/base'
require 'tap/env'

module Tap::Generator::Generators
  class Resource < Tap::Generator::Base
    
    config :test, true, &c.switch            # Specifies creation of a test file
    
    def manifest(m, const_name)
      const = Tap::Env::Constant.new(const_name.camelize)
      
      task_path = path('lib', "#{const.relative_path}.rb")
      m.directory File.dirname(task_path)
      m.template task_path, "resource.erb", :const => const
      
      if test
        test_path = path('test', "#{const.relative_path}_test.rb")
        m.directory File.dirname(test_path)
        m.template test_path, "test.erb", :const => const
      end
      
      const
    end
  end
end
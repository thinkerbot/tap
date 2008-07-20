require 'tap/root'

module Tap::Generator::Generators
  
  # ::generator
  class RootGenerator < Tap::Generator::Base
    
    def manifest(m, root, project_name=File.basename(root))
      project_name = 'project' if project_name == '.'
      r = Tap::Root.new(root)
      
      m.directory r.root
      m.directory r['lib']
      
      template_files do |source, target|
        case
        when File.directory?(source)
          m.directory r[target]
        when target == 'gemspec'
          m.template r[project_name + '.gemspec'], source, :project_name => project_name
        else
          m.template r[target], source, :project_name => project_name
        end
      end
      
      m.file(r['tap.yml']) do |file|
        Tap::App.configurations.format_str(:doc, file)
        Tap::Env.configurations.format_str(:doc, file)
      end
    end
  end
end
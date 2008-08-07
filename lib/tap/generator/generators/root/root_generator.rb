require 'tap/root'

module Tap::Generator::Generators
  
  # :startdoc::generator a basic tap directory structure
  #
  # Generates a tap root directory structure:
  #
  #   root
  #   |- Rakefile
  #   |- lib
  #   |- sample.gemspec
  #   |- tap.yml
  #   |- tapfile.rb
  #   `- test
  #       |- tap_test_helper.rb
  #       |- tap_test_suite.rb
  #       `- tapfile_test.rb
  #
  class RootGenerator < Tap::Generator::Base
    
    # ::args ROOT, PROJECT_NAME=basename(ROOT)
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
        when target == 'tapfile'
          m.template r['tapfile.rb'], source, :project_name => project_name
        else
          m.template r[target], source, :project_name => project_name
        end
      end
      
      m.file(r['tap.yml']) do |file|
       Tap::App.configurations.format_str(:doc, file) do |templater|
         next unless templater.receiver == Tap::Root
          
         templater.configurations.each do |(key, config)| 
           config.default = nil if key.to_s == 'root'
         end
       end
       Tap::Env.configurations.format_str(:doc, file)
      end
    end
  end
end
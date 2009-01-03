require 'tap/root'

module Tap::Generator::Generators
  autoload(:ConfigGenerator, 'tap/generator/generators/config/config_generator')
  
  # :startdoc: Tap::Generator::Generators::RootGenerator::generator a basic tap directory structure
  #
  # Generates a tap root directory structure.  Use the switches to 
  # generate a Tapfile and/or a tap config file:
  #
  #   root
  #   |- Rakefile
  #   |- lib
  #   |- sample.gemspec
  #   |- tap.yml
  #   |- Tapfile
  #   `- test
  #       |- tap_test_helper.rb
  #       |- tap_test_suite.rb
  #       `- tapfile_test.rb
  #
  class RootGenerator < Tap::Generator::Base
    
    config :config_file, true, &c.switch   # create a tap.yml file
    config :tapfile, false, &c.switch      # create a tapfile
    
    # ::args ROOT, PROJECT_NAME=basename(ROOT)
    def manifest(m, root, project_name=nil)
      r = Tap::Root.new(root)
      project_name = File.basename(r.root) if project_name == nil
      
      m.directory r.root
      m.directory r['lib']
      
      template_files do |source, target|
        case
        when File.directory?(source)
          m.directory r[target]
          next
        when target == 'gemspec'
          m.template r[project_name + '.gemspec'], source, :project_name => project_name, :tapfile => tapfile, :config_file => config_file
          next
        when target =~ /tapfile/i
          next unless tapfile
        end
        
        m.template r[target], source, :project_name => project_name
      end
      
     ConfigGenerator.new(:doc => true).dump(m, r['tap'], Tap::App.configurations) do |configs|
        configs.each do |(key, config)|
          config.default = nil if key.to_s == 'root'
        end
      end if config_file
    end
    
  end
end
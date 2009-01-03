require 'tap/generator/base'

module Tap::Generator::Generators
  
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
      m.directory r['test']
      
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
      
      m.file(r['tap.yml']) do |file|
        Configurable::Utils.dump(Tap::App.configurations, file) do |key, delegate|
          default = delegate.default
          
          # get the description
          desc = delegate.attributes[:desc]
          doc = desc.to_s
          doc = desc.comment if doc.empty?
          
          # wrap as lines
          lines = Lazydoc::Utils.wrap(doc, 50).collect {|line| "# #{line}"}
          lines << "" unless lines.empty?
          
          # setup formatting
          leader = key == 'root' || default == nil ? '# ' : ''
          config = {key => default}.to_yaml[5..-1]
          "#{lines.join("\n")}#{leader}#{config.strip}\n\n"
        end
      end if config_file
    end
    
  end
end
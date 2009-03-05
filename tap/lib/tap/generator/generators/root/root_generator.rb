require 'tap/generator/base'

module Tap::Generator::Generators
  
  # :startdoc: Tap::Generator::Generators::RootGenerator::generator a basic tap directory structure
  #
  # Generates a tap root directory structure.  Use the switches to turn on or
  # off the creation of various files:
  #
  #   project
  #   |- MIT-LICENSE
  #   |- README
  #   |- Rakefile
  #   |- lib
  #   |- project.gemspec
  #   |- tap.yml
  #   `- test
  #       `- tap_test_helper.rb
  #
  class RootGenerator < Tap::Generator::Base
    
    config :config_file, true, &c.switch   # Create a tap.yml file
    config :license, true, &c.switch       # Create an MIT-LICENSE
    config :rapfile, false, &c.switch      # Create a Rapfile
    
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
        when source =~ /gemspec$/
          m.template r[project_name + '.gemspec'], source, :project_name => project_name, :config_file => config_file, :license => license
          next
        when source =~ /Rapfile$/
          next unless rapfile
        when source =~ /MIT-LICENSE$/
          next unless license
        end
        
        m.template r[target], source, :project_name => project_name, :license => license
      end
      
      m.file(r['tap.yml']) do |file|
        Configurable::Utils.dump(Tap::Env.configurations, file) do |key, delegate|
          default = delegate.default(false)
          
          # get the description
          desc = delegate.attributes[:desc]
          doc = desc.to_s
          doc = desc.comment if doc.empty?
          
          # wrap as lines
          lines = Lazydoc::Utils.wrap(doc, 78).collect {|line| "# #{line}"}
          lines << "" unless lines.empty?
          
          # note: this causes order to be lost...
          default = default.to_hash if delegate.is_nest?

          # setup formatting
          leader = key == 'root' || default == nil ? '# ' : ''
          config = YAML.dump({key => default})[5..-1].strip.gsub(/\n+/, "\n#{leader}")
          "#{lines.join("\n")}#{leader}#{config}\n\n"
        end
      end if config_file
    end
    
  end
end
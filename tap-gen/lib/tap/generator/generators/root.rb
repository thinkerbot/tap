require 'tap/generator/base'
require 'tap/version'

module Tap::Generator::Generators
  
  # :startdoc::generator a basic tap directory structure
  #
  # Generates a tap root directory structure.  Use the switches to turn on or
  # off the creation of various files:
  #
  #   project
  #   |- MIT-LICENSE
  #   |- README
  #   |- lib
  #   |- project.gemspec
  #   |- tapfile
  #   |- tap.yml
  #   `- test
  #       `- tap_test_helper.rb
  #
  class Root < Tap::Generator::Base
    
    nest :gemspec do
      config :name, "Your Name Here"               # Author name
      config :email, "your.email@pubfactory.edu"   # Author email
      config :homepage, ""                         # The project hompage
      config :rubyforge_project, ""                # The rubyforge project name
      config :summary, ""                          # The project summary
    end
    
    config :env, false, &c.switch          # Create a full tap.yml file
    config :license, true, &c.switch       # Create an MIT-LICENSE
    config :history, true, &c.switch       # Create History file
    config :tapfile, true, &c.switch       # Create a Tapfile
    
    # ::args ROOT, PROJECT_NAME=basename(ROOT)
    def manifest(m, root, project_name=nil)
      r = destination_root.root(root)
      project_name = File.basename(r.path) if project_name == nil
      
      m.directory r.path
      m.directory r.path('lib')
      m.directory r.path('test')
      
      template_files do |source, target|
        case
        when File.directory?(source)
          m.directory r.path(target)
          next
        when source =~ /gemspec$/
          locals = gemspec.config.to_hash.merge(
            :project_name => project_name, 
            :license => license,
            :history => history
          )
          m.template r.path("#{project_name}.gemspec"), source, locals
          next
        when source =~ /tapfile$/
          next unless tapfile
        when source =~ /MIT-LICENSE$/
          next unless license
        end
        
        m.template r.path(target), source, :project_name => project_name, :license => license
      end
      
      m.file(r.path('History')) if history
    end
    
  end
end
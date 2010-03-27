require 'tap/generator/base'

module Tap
  module Generator
    module Generators
      # :startdoc::generator make a faster tap
      class Tap < Tap::Generator::Base
        
        config :name, 'tap', &c.string            # sets the tap executable name
        config :profile, 'profile.sh', &c.string  # sets the profile script name
        
        def manifest(m)
          load_paths = load_paths('lazydoc', 'configurable', 'tap')
          bin_path = File.join(load_paths.last.chomp('lib'), 'bin/tap')
          
          m.template name, 'tap.erb', {
            :load_paths => load_paths,
            :bin_path => bin_path
          }
          
          m.on(:generate) do 
            log :chmod, "0755 #{name}"
            FileUtils.chmod(0755, name)
          end
          
          m.template profile, 'profile.erb', {
            :generator => self.class,
            :filename => profile
          }
        end
        
        def load_paths(*gem_names)
          gem_names.collect! do |gem_name|
            load_path = $LOAD_PATH.find do |path|
              path =~ /\/#{gem_name}[-\d\.]*\/lib$/
            end
            
            if load_path.nil?
              raise "could not determine load path for: #{gem_name}"
            end
            
            File.expand_path(load_path)
          end
        end
        
      end 
    end
  end
end

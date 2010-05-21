#############################################################################
# Dependencies in this Gemfile are managed through the gemspecs for each
# module.  Add/remove depenencies there, rather than editing this file ex:
#
#   Gem::Specification.new do |s|
#     ... 
#     s.add_dependency("rack")
#     s.add_development_dependency("rack-test")
#   end
#
#############################################################################

source :gemcutter
path '.', :glob => '*/*.gemspec'

#
# Setup gemspec dependencies
#

pattern = File.expand_path("../tap*/*.gemspec", __FILE__)
Dir.glob(pattern).each do |gemspec_path|
  project_dir = File.dirname(gemspec_path)
  project_grp = File.basename(project_dir)
  
  Dir.chdir(project_dir) do
    group project_grp do 
      gemspec = eval File.read(gemspec_path)
  
      gemspec.dependencies.each do |dep|
        gem dep.name, dep.requirement
      end
  
      gem gemspec.name, gemspec.version
    end
  end
end

#
# Test helper
#

module ::Bundler
  class Runtime < Environment
    def load_paths(*groups)
      groups.collect! {|group| group.to_sym }
      libs = specs_for(groups).collect {|spec| spec.load_paths }.flatten.uniq
      libs.collect {|lib| ['-I', lib] }.flatten
    end
  end
end
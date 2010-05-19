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
path '.', :glob => '{configurable,lazydoc}/*.gemspec'

$:.unshift File.expand_path('../lazydoc/lib', __FILE__)
$:.unshift File.expand_path('../configurable/lib', __FILE__)

#
# Setup gemspec dependencies
#

%w{
  tap
  tap-gen
  tap-tasks
  tap-test
}.each do |project|
  project_path = File.expand_path("../#{project}", __FILE__)
  Dir.chdir(project_path) do
    gemspec = eval(File.read("#{project_path}/#{project}.gemspec"))
  
    gemspec.dependencies.each do |dep|
      group = dep.type == :development ? :development : :default
      gem dep.name, dep.requirement, :group => group
    end
  
    gem(gemspec.name, gemspec.version, :path => project_path)
  end
end

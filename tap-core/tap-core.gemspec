Gem::Specification.new do |s|
  s.name = "tap-core"
  s.version = "0.12.0"
  s.author = "Simon Chiang"
  s.email = "simon.a.chiang@gmail.com"
  s.homepage = "http://tap.rubyforge.org"
  s.platform = Gem::Platform::RUBY
  s.summary = "The core functionality of the tap framework."
  s.require_path = "lib"
  s.rubyforge_project = "tap"
  s.bindir = "bin"
  s.executables = "tap"
  s.add_dependency("configurable", ">= 0.2.1")
  s.has_rdoc = true
  s.rdoc_options << '--title' << 'Tap Core' << '--main' << 'README' 
   
  s.extra_rdoc_files = %W{
    README
    MIT-LICENSE
    History
    doc/Class\sReference
    doc/Command\sReference
    doc/Syntax\sReference}
  
  s.files = %W{
    cmd/console.rb
    cmd/manifest.rb
    cmd/run.rb
    bin/tap
    lib/tap/app.rb
    lib/tap/constants.rb
    lib/tap/env.rb
    lib/tap/exe.rb
    lib/tap/file_task.rb
    lib/tap/root.rb
    lib/tap/support/aggregator.rb
    lib/tap/support/audit.rb
    lib/tap/support/combinator.rb
    lib/tap/support/constant.rb
    lib/tap/support/constant_manifest.rb
    lib/tap/support/dependencies.rb
    lib/tap/support/dependency.rb
    lib/tap/support/executable.rb
    lib/tap/support/executable_queue.rb
    lib/tap/support/gems.rb
    lib/tap/support/intern.rb
    lib/tap/support/join.rb
    lib/tap/support/joins.rb
    lib/tap/support/joins/fork.rb
    lib/tap/support/joins/merge.rb
    lib/tap/support/joins/sequence.rb
    lib/tap/support/joins/switch.rb
    lib/tap/support/joins/sync_merge.rb
    lib/tap/support/manifest.rb
    lib/tap/support/minimap.rb
    lib/tap/support/node.rb
    lib/tap/support/parser.rb
    lib/tap/support/schema.rb
    lib/tap/support/shell_utils.rb
    lib/tap/support/string_ext.rb
    lib/tap/support/templater.rb
    lib/tap/support/versions.rb
    lib/tap/task.rb
    lib/tap/tasks/dump.rb
    lib/tap/tasks/load.rb
    lib/tap.rb
    _tap.yml
    }
end
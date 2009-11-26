Gem::Specification.new do |s|
  s.name = "tap"
  s.version = "0.18.1"
  s.author = "Simon Chiang"
  s.email = "simon.a.chiang@gmail.com"
  s.homepage = "http://tap.rubyforge.org"
  s.platform = Gem::Platform::RUBY
  s.summary = "A configurable, distributable workflow framework."
  s.require_path = "lib"
  s.rubyforge_project = "tap"
  s.bindir = "bin"
  s.executables = "tap"
  s.add_dependency("configurable", ">= 0.5.0")
  s.has_rdoc = true
  s.rdoc_options.concat %W{--main README -S -N --title Tap\s(Task\sApplication)}
   
  s.extra_rdoc_files = %W{
    README
    MIT-LICENSE
    History
    doc/API
    doc/Class\sReference
    doc/Examples/Command\sLine
    doc/Examples/Workflow}
  
  s.files = %W{
    cmd/console.rb
    cmd/manifest.rb
    cmd/run.rb
    doc/tap/app/help.erb
    doc/tap/app/list.erb
    doc/tap/app/tutorial.erb
    lib/tap.rb
    lib/tap/app.rb
    lib/tap/app/api.rb
    lib/tap/app/doc.rb
    lib/tap/app/node.rb
    lib/tap/app/queue.rb
    lib/tap/app/stack.rb
    lib/tap/app/state.rb
    lib/tap/env.rb
    lib/tap/env/constant.rb
    lib/tap/env/context.rb
    lib/tap/env/gems.rb
    lib/tap/env/manifest.rb
    lib/tap/env/minimap.rb
    lib/tap/env/string_ext.rb
    lib/tap/intern.rb
    lib/tap/join.rb
    lib/tap/joins.rb
    lib/tap/joins/switch.rb
    lib/tap/joins/sync.rb
    lib/tap/middleware.rb
    lib/tap/middlewares/debugger.rb
    lib/tap/middlewares/tracer.rb
    lib/tap/parser.rb
    lib/tap/root.rb
    lib/tap/root/utils.rb
    lib/tap/root/versions.rb
    lib/tap/signals.rb
    lib/tap/signals/class_methods.rb
    lib/tap/signals/help.rb
    lib/tap/signals/module_methods.rb
    lib/tap/signals/signal.rb
    lib/tap/task.rb
    lib/tap/tasks/dump.rb
    lib/tap/tasks/load.rb
    lib/tap/templater.rb
    lib/tap/version.rb
    }
end
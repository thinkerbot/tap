require File.expand_path('../lib/tap/version', __FILE__)

Gem::Specification.new do |s|
  s.name = 'tap'
  s.version = Tap::VERSION
  s.author = 'Simon Chiang'
  s.email = 'simon.a.chiang@gmail.com'
  s.homepage = Tap::WEBSITE
  s.platform = Gem::Platform::RUBY
  s.summary = 'A configurable, distributable workflow framework.'
  s.require_path = 'lib'
  s.rubyforge_project = 'tap'
  s.bindir = 'bin'
  s.executables = 'tap'
  s.add_dependency('configurable', '>= 0.6.0')
  s.has_rdoc = true
  s.rdoc_options.concat %W{--main README -S -N --title Tap\s(Task\sApplication)}
   
  s.extra_rdoc_files = %W{
    README
    MIT-LICENSE
    History
    doc/API
    doc/Workflow\sSyntax
    doc/Ruby\sto\sRuby
    doc/Examples/Command\sLine
    doc/Examples/Tapfile
    doc/Configuration}
  
  s.files = %W{
    bin/tapexe
    lib/tap.rb
    lib/tap/app.rb
    lib/tap/app/api.rb
    lib/tap/app/env.rb
    lib/tap/app/node.rb
    lib/tap/app/queue.rb
    lib/tap/app/stack.rb
    lib/tap/app/state.rb
    lib/tap/declarations.rb
    lib/tap/declarations/description.rb
    lib/tap/env.rb
    lib/tap/env/cache.rb
    lib/tap/env/constant.rb
    lib/tap/env/path.rb
    lib/tap/env/string_ext.rb
    lib/tap/join.rb
    lib/tap/joins/gate.rb
    lib/tap/joins/switch.rb
    lib/tap/joins/sync.rb
    lib/tap/middleware.rb
    lib/tap/middlewares/debugger.rb
    lib/tap/parser.rb
    lib/tap/root.rb
    lib/tap/signal.rb
    lib/tap/signals.rb
    lib/tap/signals/class_methods.rb
    lib/tap/signals/configure.rb
    lib/tap/signals/help.rb
    lib/tap/signals/load.rb
    lib/tap/signals/module_methods.rb
    lib/tap/task.rb
    lib/tap/tasks/dump.rb
    lib/tap/tasks/load.rb
    lib/tap/tasks/manifest.rb
    lib/tap/tasks/prompt.rb
    lib/tap/tasks/singleton.rb
    lib/tap/tasks/stream.rb
    lib/tap/templater.rb
    lib/tap/utils.rb
    lib/tap/version.rb
    lib/tap/workflow.rb
    tap.yml
    }
end
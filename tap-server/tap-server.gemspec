$:.unshift File.expand_path('../../tap/lib', __FILE__)
$:.unshift File.expand_path('../../tap-test/lib', __FILE__)
$:.unshift File.expand_path('../../tap-server/lib', __FILE__)

require 'tap/version'
require 'tap/test/version'
require 'tap/server/version'

$:.shift
$:.shift
$:.shift

Gem::Specification.new do |s|
  s.name = 'tap-server'
  s.version = Tap::Server::VERSION
  s.author = 'Simon Chiang'
  s.email = 'simon.a.chiang@gmail.com'
  s.homepage = File.join(Tap::WEBSITE, 'tap-server')
  s.platform = Gem::Platform::RUBY
  s.summary = 'A web interface for tap.'
  s.require_path = 'lib'
  s.rubyforge_project = 'tap'
  s.has_rdoc = true
  s.rdoc_options.concat %W{--main README -S -N --title Tap\sServer}
  
  s.add_dependency('tap', ">= #{Tap::VERSION}")
  s.add_dependency('rack', '>= 1.0')
  s.add_dependency('em-websocket')
  s.add_development_dependency('tap-test', ">= #{Tap::Test::VERSION}")
  
  s.extra_rdoc_files = %W{
    README
    MIT-LICENSE
    History}
  
  s.files = %W{
    cmd/server.rb
    lib/tap/controller.rb
    lib/tap/controller/extname.rb
    lib/tap/controller/rest_routes.rb
    lib/tap/controller/utils.rb
    lib/tap/controllers/app.rb
    lib/tap/controllers/data.rb
    lib/tap/controllers/server.rb
    lib/tap/generator/generators/controller.rb
    lib/tap/server.rb
    lib/tap/server/data.rb
    lib/tap/server/server_error.rb
    lib/tap/tasks/echo.rb
    lib/tap/tasks/render.rb
    public/stylesheets/tap.css
    tap.yml
    templates/tap/generator/generators/controller/resource.erb
    templates/tap/generator/generators/controller/test.erb
    templates/tap/generator/generators/controller/view.erb
    views/404.erb
    views/500.erb
    views/configurable/configurations.erb
    views/configurable/default.erb
    views/layout.erb
    views/object/obj.erb
    views/tap/app/api/help.erb
    views/tap/controller/help.erb
    views/tap/controllers/app/index.erb
    views/tap/controllers/data/_controls.erb
    views/tap/controllers/data/_upload.erb
    views/tap/controllers/data/entry.erb
    views/tap/controllers/data/index.erb
    views/tap/controllers/server/access.erb
    views/tap/controllers/server/admin.erb
    views/tap/controllers/server/index.erb
    views/tap/signals/signal/get.erb
    views/tap/signals/signal/index.erb
    views/tap/signals/signal/post.erb
    }
end
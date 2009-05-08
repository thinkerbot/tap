Gem::Specification.new do |s|
  s.name = "tap-server"
  s.version = "0.3.0"
  s.author = "Simon Chiang"
  s.email = "simon.a.chiang@gmail.com"
  s.homepage = "http://tap.rubyforge.org"
  s.platform = Gem::Platform::RUBY
  s.summary = "A web interface for tap."
  s.require_path = "lib"
  s.rubyforge_project = "tap"
  s.add_dependency("tap", ">= 0.12.3")
  s.add_dependency("rack", ">= 0.9.1")
  s.has_rdoc = true
  s.rdoc_options.concat %W{--main README -S -N --title Tap\sServer}
  
  s.extra_rdoc_files = %W{
    README
    MIT-LICENSE
    History}
  
  s.files = %W{
    cmd/app.rb
    cmd/client.rb
    cmd/server.rb
    lib/tap/app/api.rb
    lib/tap/app/client.rb
    lib/tap/app/server.rb
    lib/tap/controller.rb
    lib/tap/controller/rest_routes.rb
    lib/tap/controller/session.rb
    lib/tap/controllers/schema.rb
    lib/tap/controllers/server.rb
    lib/tap/server.rb
    lib/tap/server/base.rb
    lib/tap/server/persistence.rb
    lib/tap/server/server_error.rb
    lib/tap/server/session.rb
    lib/tap/server/utils.rb
    lib/tap/tasks/echo.rb
    public/javascripts/prototype.js
    public/javascripts/tap.js
    public/stylesheets/tap.css
    tap.yml
    views/404.erb
    views/500.erb
    views/layout.erb
    views/tap/app/server/_action.erb
    views/tap/app/server/about.erb
    views/tap/app/server/build.erb
    views/tap/app/server/enque.erb
    views/tap/app/server/info.erb
    views/tap/controllers/schema/configurations.erb
    views/tap/controllers/schema/configurations/default.erb
    views/tap/controllers/schema/configurations/flag.erb
    views/tap/controllers/schema/configurations/list.erb
    views/tap/controllers/schema/configurations/list_select.erb
    views/tap/controllers/schema/configurations/regexp.erb
    views/tap/controllers/schema/configurations/select.erb
    views/tap/controllers/schema/configurations/switch.erb
    views/tap/controllers/schema/index.erb
    views/tap/controllers/schema/join.erb
    views/tap/controllers/schema/round.erb
    views/tap/controllers/schema/schema.erb
    views/tap/controllers/server/about.erb
    views/tap/controllers/server/build.erb
    views/tap/controllers/server/enque.erb
    views/tap/controllers/server/index.erb
    views/tap/controllers/server/info.erb
    views/tap/controllers/server/tail.erb
    }
end
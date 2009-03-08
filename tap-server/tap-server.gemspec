Gem::Specification.new do |s|
  s.name = "tap-server"
  s.version = "0.2.0"
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
    cmd/server.rb
    lib/tap/controller.rb
    lib/tap/controllers/app.rb
    lib/tap/controllers/schema.rb
    lib/tap/server.rb
    lib/tap/server_error.rb
    lib/tap/tasks/echo.rb
    lib/tap/tasks/server.rb
    public/javascripts/prototype.js
    public/javascripts/tap.js
    public/stylesheets/tap.css
    tap.yml
    views/404.erb
    views/500.erb
    views/layout.erb
    views/tap/controllers/app/index.erb
    views/tap/controllers/app/info.erb
    views/tap/controllers/app/tail.erb
    views/tap/controllers/schema/config/default.erb
    views/tap/controllers/schema/config/flag.erb
    views/tap/controllers/schema/config/switch.erb
    views/tap/controllers/schema/configurations.erb
    views/tap/controllers/schema/join.erb
    views/tap/controllers/schema/node.erb
    views/tap/controllers/schema/preview.erb
    views/tap/controllers/schema/round.erb
    views/tap/controllers/schema/schema.erb
    views/tap/tasks/echo/result.html
    }
end
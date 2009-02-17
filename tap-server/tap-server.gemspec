Gem::Specification.new do |s|
  s.name = "tap-server"
  s.version = "0.1.0"
  s.author = "Simon Chiang"
  s.email = "simon.a.chiang@gmail.com"
  s.homepage = "http://tap.rubyforge.org"
  s.platform = Gem::Platform::RUBY
  s.summary = "A web interface for tap."
  s.require_path = "lib"
  s.rubyforge_project = "tap"
  s.add_dependency("tap", ">= 0.12.0")
  s.add_dependency("rack", ">= 0.9.1")
  s.has_rdoc = true
  s.rdoc_options.concat %W{--main README -S -N --title Tap\sServer}
  
  s.extra_rdoc_files = %W{
    README
    MIT-LICENSE
    History}
  
  s.files = %W{
    cmd/server.rb
    controllers/app_controller.rb
    controllers/schema_controller.rb
    lib/tap/controller.rb
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
    views/app_controller/index.erb
    views/app_controller/info.erb
    views/app_controller/tail.erb
    views/layout.erb
    views/schema_controller/config/default.erb
    views/schema_controller/config/flag.erb
    views/schema_controller/config/switch.erb
    views/schema_controller/configurations.erb
    views/schema_controller/join.erb
    views/schema_controller/node.erb
    views/schema_controller/preview.erb
    views/schema_controller/round.erb
    views/schema_controller/schema.erb
    views/tap/tasks/echo/result.html
    }
end
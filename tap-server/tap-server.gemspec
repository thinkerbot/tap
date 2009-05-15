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
    data/results.txt
    lib/tap/controller.rb
    lib/tap/controller/rest_routes.rb
    lib/tap/controller/utils.rb
    lib/tap/controllers/app.rb
    lib/tap/controllers/data.rb
    lib/tap/controllers/schema.rb
    lib/tap/controllers/server.rb
    lib/tap/router.rb
    lib/tap/server.rb
    lib/tap/server/data.rb
    lib/tap/server/server_error.rb
    lib/tap/tasks/echo.rb
    lib/tap/tasks/render.rb
    public/javascripts/prototype.js
    public/javascripts/tap.js
    public/stylesheets/tap.css
    tap.yml
    views/404.erb
    views/500.erb
    views/configurable/_config.erb
    views/configurable/_configs.erb
    views/configurable/_flag.erb
    views/configurable/_list_select.erb
    views/configurable/_select.erb
    views/configurable/_switch.erb
    views/layout.erb
    views/object/obj.erb
    views/tap/controllers/app/_action.erb
    views/tap/controllers/app/build.erb
    views/tap/controllers/app/enque.erb
    views/tap/controllers/app/info.erb
    views/tap/controllers/app/tail.erb
    views/tap/controllers/data/_controls.erb
    views/tap/controllers/data/_index_entry.erb
    views/tap/controllers/data/_upload.erb
    views/tap/controllers/data/data.erb
    views/tap/controllers/data/index.erb
    views/tap/controllers/schema/_build.erb
    views/tap/controllers/schema/_index_entry.erb
    views/tap/controllers/schema/join.erb
    views/tap/controllers/schema/schema.erb
    views/tap/controllers/schema/task.erb
    views/tap/controllers/server/access.erb
    views/tap/controllers/server/admin.erb
    views/tap/controllers/server/help.erb
    views/tap/controllers/server/index.erb
    views/tap/task/input.erb
    }
end
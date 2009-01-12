Gem::Specification.new do |s|
  s.name = "tap-server"
  s.version = "0.12.0"
  s.author = "Simon Chiang"
  s.email = "simon.a.chiang@gmail.com"
  s.homepage = "http://tap.rubyforge.org"
  s.platform = Gem::Platform::RUBY
  s.summary = "A web interface for Tap."
  s.require_path = "lib"
  s.rubyforge_project = "tap"
  s.add_dependency("tap", ">= 0.12.0")
  s.add_dependency("rack", ">= 0.9.1")
  s.bindir = "bin"
  s.executables = "rap"
  s.has_rdoc = true
  s.rdoc_options << '--title' << 'Tap Server' << '--main' << 'README' 
   
  s.extra_rdoc_files = %W{
    README
    MIT-LICENSE
    History}
  
  s.files = %W{
    cgi/run.rb
    cmd/server.rb
    lib/tap/server.rb
    public/javascripts/prototype.js
    public/javascripts/run.js
    public/stylesheets/run.css
    tap.yml
    template/404.erb
    template/index.erb
    template/run.erb
    template/run/join.erb
    template/run/manifest.erb
    template/run/node.erb
    template/run/round.erb
    vendor/url_encoded_pair_parser.rb
    }
end
require 'tap/generator/base'

# :startdoc::generator generates an example post
#
# Generates a new example post in the _posts directory.
class Example < Tap::Generator::Base
  
  config :format, "textile"    # the markup extension
  config :layout, "page.html"  # the page layout
  
  def manifest(m, title)
    m.directory "_posts"
    
    date = Time.now.strftime("%Y-%m-%d")
    m.template  "_posts/#{date}-#{title}.#{format}", "example.erb", :yaml => {'layout' => layout}
  end
end 

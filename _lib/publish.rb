require 'tap/task'
require 'yaml'

# ::task publish website
class Publish < Tap::Task
  include Tap::Utils
  
  def process
    sh 'jekyll'
    
    config = YAML.load_file File.expand_path('~/.rubyforge/user-config.yml')
    username = config['username']
    
    sh "rsync -v -c -r _site/ #{username}@rubyforge.org:/var/www/gforge-projects/tap"
  end
end
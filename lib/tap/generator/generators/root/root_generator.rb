require 'tap/root'

module Tap::Generator::Generators
  class RootGenerator < Rails::Generator::NamedBase # :nodoc:
    def initialize(*args)
      super(*args)   
      Tap::App.instance.root = File.join(Tap::App.instance[:root], class_path, file_name)
      @destination_root  = Tap::App.instance[:root]
  	end

    def manifest
      record do |m|
        # directories
        m.directory "lib"
        #m.directory "config"
        m.directory "test"

        # remove these -- they will be created from
        # a server generator in the future
        #m.directory "server/config"
        #m.directory "server/test"
        #m.directory "server/lib/tasks"
    
        # files
        template_dir = File.dirname(__FILE__) + "/templates"
        Dir.glob(template_dir + "/**/*").each do |fname|
          next if File.directory?(fname)
          
          # skip server files for now... later 
          # the files will simply be removed
          next if fname =~ /server/
          next if fname =~ /config/
          next if fname =~ /process_tap_request/
      
          fname = Tap::Root.relative_filepath(template_dir, fname)
          m.template fname, fname
        end
      end
    end
  end
end
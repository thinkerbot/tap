module Tap::Generator::Generators
  
  # ::generator
  #
  # Generates a new Tap command under the cmd directory. Pass 
  # the command name, either CamelCased or under_scored.  The  
  # new command can be run from the command line using:
  # 
  #   % tap <command name>
  class CommandGenerator < Tap::Generator::Base
    
    def manifest(m, command_name)

      m.directory app['cmd']
      
      template_files do |source, target|
        m.template app.filepath('cmd', "#{command_name}.rb"), source, :command_name => command_name
      end
    end
    
  end
end
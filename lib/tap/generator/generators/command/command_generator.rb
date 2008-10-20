module Tap::Generator::Generators
  
  # :startdoc: Tap::Generator::Generators::CommandGenerator::generator a new tap command
  #
  # Generates a new tap command under the cmd directory. The  
  # new command can be run from the command line using:
  # 
  #   % tap <command>
  #
  class CommandGenerator < Tap::Generator::Base
    
    def manifest(m, command_name)
      m.directory app['cmd']
      
      template_files do |source, target|
        m.template app.filepath('cmd', "#{command_name}.rb"), source, :command_name => command_name
      end
    end
    
  end
end

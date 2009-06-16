require 'tap/generator/base'

module Tap::Generator::Generators
  
  # :startdoc::generator a new tap command
  #
  # Generates a new tap command under the cmd directory. The  
  # new command can be run from the command line using:
  # 
  #   % tap <command>
  #
  class Command < Tap::Generator::Base
    def manifest(m, command_name)
      m.directory path('cmd')
      
      template_files do |source, target|
        m.template path('cmd', "#{command_name}.rb"), source, :command_name => command_name
      end
    end
  end
end

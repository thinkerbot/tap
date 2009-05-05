require 'tap/task'
require 'stringio'

module Tap
  module Tasks
    # :startdoc::task the default load task
    #
    # Loads data from $stdin.  String data may be passed directly.  Load
    # is typically used as a gateway to other tasks.
    #
    #   % tap run -- load string --: dump
    #   string
    #
    # Load facilitates normal redirection:
    #
    #   % echo goodnight moon | tap run -- load --: dump
    #   goodnight moon
    #
    #   % tap run -- load --: dump < somefile.txt
    #   contents of somefile
    #
    # ::task-
    #
    # Load serves as a baseclass for more complicated loads.  A YAML load
    # (see {tap-tasks}[http://tap.rubyforge.org/tap-tasks]) looks like this:
    #
    #   class Yaml < Tap::Load
    #     def load(io)
    #       YAML.load(io)
    #     end
    #   end
    #
    class Load < Tap::Task
    
      # The default process simply reads the input data and returns it.
      # See load.
      def process(io=$stdin)
        # read on an empty stdin ties up the command line;
        # this facilitates the intended behavior
        if io.kind_of?(IO) && io.stat.size == 0
          io = '' 
        end
      
        if io.kind_of?(String)
          io = StringIO.new(io)
        end
      
        open_io(io) do |data|
          load(data)
        end
      end
    
      # Loads data from the io; the return of load is the return of process.  By
      # default load simply reads data from io.
      def load(io)
        io.read
      end
    end
  end
end

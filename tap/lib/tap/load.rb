require 'tap/task'
require 'stringio'

module Tap
  # :startdoc::task the default load task
  #
  # Loads data from the input IO; string data is simply passed through.  Load
  # is typically used as a gateway to other tasks.
  #
  #   % tap run -- load string --: dump
  #   string
  #
  # Note that load takes $stdin by default, so you can pipe or redirect data
  # into to a workflow:
  #
  #   % echo goodnight moon | tap run -- load --: dump
  #   goodnight moon
  #
  #   % tap run -- load --: dump < somefile.txt
  #   contents of somefile
  #
  # ::task-
  #
  # Load serves as a baseclass for more complicated load tasks.  A YAML load
  # task (see {tap-tasks}[http://tap.rubyforge.org/tap-tasks]) looks like this:
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
    def process(input=$stdin)
      # read on an empty stdin ties up the command line;
      # this facilitates the intended behavior
      if input.kind_of?(IO) && input.stat.size == 0
        input = '' 
      end
      
      if input.kind_of?(String)
        input = StringIO.new(input)
      end
      
      open_io(input) do |io|
        load(io)
      end
    end
    
    # Loads data from the io; the return of load is the return of process.  By
    # default load simply reads data from io.
    def load(io)
      io.read
    end
  end 
end

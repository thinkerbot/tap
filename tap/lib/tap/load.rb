require 'tap/task'
require 'stringio'

module Tap
  # :startdoc::manifest the default load task
  #
  # Loads data from the input IO; string data is simply passed through.  Load
  # is typically used as a gateway to other tasks.
  #
  #   % tap run -- load string --: dump
  #
  # String is taken literally as the input unless identified as a filepath.
  # This will load data from FILE.  
  #
  #   % tap run -- load FILE --file --: dump
  #
  # Note that load takes $stdin by default, so you can pipe or redirect data
  # into to a workflow like so:
  #
  #   % echo 'hello' | tap run -- load --: dump --audit
  #   # audit:
  #   # o-[tap/load] "hello\n"
  #   # o-[tap/dump] ["hello\n"]
  #   #
  #   hello
  #
  #   % tap run -- load --: dump --audit < 'somefile.txt'
  #   # audit:
  #   # o-[tap/load] "contents of somefile\n"
  #   # o-[tap/dump] ["contents of somefile\n"]
  #   #
  #   contents of somefile
  #
  # ::manifest-
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

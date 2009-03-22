module Tap
  # :startdoc::manifest the default load task
  #
  # Loads data from the input IO or filepath.  Load is typically used
  # as a gateway to other tasks.
  #
  #   % tap run -- load FILEPATH --: [task]
  #
  # Note that load can be used as the target of pipe:
  #
  #   % echo 'hello' | tap run -- load --: dump --audit
  #   # audit:
  #   # o-[tap/tasks/load] "hello\n"
  #   # o-[tap/tasks/dump] ["hello\n"]
  #   #
  #   hello
  #
  class Load < Tap::Task
    
    def process(input=$stdin)
      case input
      when StringIO, IO
        load(input)
      else
        log :load, input
        load(StringIO.new(input))
      end
    end
    
    def load(io)
      io.read
    end
  end 
end

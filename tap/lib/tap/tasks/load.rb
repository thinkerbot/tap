module Tap
  module Tasks
    # :startdoc::manifest the default load task
    #
    # Loads data from the input IO or filepath.  YAML-formatted data may be
    # loaded by specifying the --yaml configuration.  Load is typically used
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
      
      config :yaml, false, &c.switch             # Load as yaml (vs string)
      
      # Loads the input as YAML.  Input may be an IO, StringIO, or a filepath.
      # The loaded object is returned directly.
      def process(input=$stdin)
        str = case input
        when StringIO, IO
          input.read
        else
          log :load, input
          File.read(input)
        end
        
        yaml ? YAML.load(str) : str
      end
    end 
  end
end

module Tap
  module Tasks
    # :startdoc::manifest the default load task
    #
    # Loads YAML-formatted data and makes the result available for other tasks.
    # Use the --no-yaml configuration to read the data without loading as YAML.
    #
    # Load is typically used as a gateway task to other tasks.
    #
    #   % tap run -- load FILEPATH --: [task]
    #
    class Load < Tap::Task
      
      config :yaml, true, &c.switch              # load as yaml (vs string)
      
      # Loads the input as YAML.  Input may be an IO, StringIO, or a filepath.
      # The loaded object is returned directly.
      def process(input)
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

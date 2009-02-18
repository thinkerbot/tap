module Tap
  module Tasks
    # :startdoc::manifest the default load task
    #
    # Loads YAML-formatted data and makes the result available for other tasks.
    # Load is typically used as a gateway task to other tasks.
    #
    #   % tap run -- load FILEPATH --: [task]
    #
    class Load < Tap::Task
      
      # Loads the input as YAML.  Input may be an IO, StringIO, or a filepath.
      # The loaded object is returned directly.
      def process(input)
        case input
        when StringIO, IO
          YAML.load(input.read)
        else
          log :load, input
          YAML.load_file(input)
        end
      end
    end 
  end
end

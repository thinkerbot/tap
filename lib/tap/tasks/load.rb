module Tap
  module Tasks
    # :startdoc::manifest the default load task
    #
    # Load YAML-formatted data, as may be produced using Tap::Dump,
    # and makes this data available for other tasks.  Load is often
    # used as a gateway task to other tasks.
    #
    #   % tap run -- load FILEPATH --: [task]
    #
    class Load < Tap::Task

      def process(input)
        obj = case input
        when StringIO then YAML.load(input.read)
        else
          log :load, input
          YAML.load_file(input)
        end
        
        obj.values.flatten
      end
    end 
  end
end

require 'tap/load'

module Tap
  module Tasks
    module Load
      
      # :startdoc::manifest loads data as YAML
      #
      # Loads data from the input IO as YAML.  See the default tap load task
      # for more details.
      #
      #   % tap run -- load/yaml "{key: value}" --: dump/yaml
      #   ---
      #   key: value
      #
      class Yaml < Tap::Load
        
        # Loads data from io as YAML.
        def load(io)
          YAML.load(io)
        end
      end
    end
  end
end
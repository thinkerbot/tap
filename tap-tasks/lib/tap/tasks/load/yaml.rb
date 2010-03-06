require 'tap/tasks/load'

module Tap
  module Tasks
    class Load
      
      # :startdoc::task loads data as YAML
      #
      # Loads data from the input IO as YAML.
      #
      #   % tap load/yaml "{key: value}" --: dump/yaml
      #   --- 
      #   key: value
      #
      class Yaml < Load
        
        # Loads data from io as YAML.
        def load(io)
          YAML.load(io)
        end
        
      end
    end
  end
end
require 'tap/tasks/dump'

module Tap
  module Tasks
    class Dump
      
      # :startdoc::task dumps data as YAML
      #
      # Dumps workflow results to a file or IO as YAML.
      #
      #   % tap run -- load/yaml "{key: value}" --: dump/yaml
      #   --- 
      #   key: value
      #
      class Yaml < Dump
        
        # Dumps the object to io as YAML.
        def dump(obj, io)
          YAML.dump(obj, io)
        end
      end
    end
  end
end
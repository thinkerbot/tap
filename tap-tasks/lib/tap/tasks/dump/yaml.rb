require 'tap/dump'

module Tap
  module Tasks
    module Dump
      
      # :startdoc::manifest dumps data as YAML
      #
      # Dumps workflow results to a file or IO as YAML.  See the default tap
      # dump task for more details.
      #
      #   % tap run -- load/yaml "{key: value}" --: dump/yaml
      #   ---
      #   key: value
      #
      class Yaml < Tap::Dump
        
        # Dumps the object to io as YAML.
        def dump(obj, io)
          YAML.dump(obj, io)
        end
      end
    end
  end
end
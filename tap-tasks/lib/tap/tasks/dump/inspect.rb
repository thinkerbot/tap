require 'tap/dump'

module Tap
  module Tasks
    module Dump
      
      # :startdoc::manifest inspect and dump an object
      #
      # Dumps objects to a file or IO using object.inspect.  See the default
      # tap dump task for more details.
      #
      #   % tap run -- load/yaml "{key: value}" --: inspect
      #   {"key"=>"value"}
      #
      class Inspect < Tap::Dump
        
        # Dumps the object to io using obj.inspect
        def dump(obj, io)
          io.puts obj.inspect
        end
      end
    end
  end
end
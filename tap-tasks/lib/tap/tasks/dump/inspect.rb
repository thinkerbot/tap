require 'tap/dump'

module Tap
  module Tasks
    module Dump
      
      # :startdoc::manifest inspect and dump an object
      #
      # Dumps objects to a file or IO using object.inspect.  An alternate
      # method can be specified for inspection using the inspect_method
      # config.  See the default tap dump task for more details.
      #
      #   % tap run -- load/yaml "{key: value}" --: inspect
      #   {"key"=>"value"}
      #
      #   % tap run -- load string --: inspect -m length
      #   6
      #
      class Inspect < Tap::Dump
        
        config :inspect_method, 'inspect', :short => :m    # The inspection method
        
        # Dumps the object to io using obj.inspect
        def dump(obj, io)
          io.puts obj.send(inspect_method)
        end
      end
    end
  end
end
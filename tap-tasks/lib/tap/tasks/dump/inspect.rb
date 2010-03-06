require 'tap/tasks/dump'

module Tap
  module Tasks
    class Dump
      
      # :startdoc::task inspect and dump an object
      #
      # Dumps objects to a file or IO using object.inspect.  An alternate
      # method can be specified for inspection using the inspect_method
      # config.
      #
      #   % tap load/yaml "{key: value}" -: inspect
      #   {"key"=>"value"}
      #
      class Inspect < Dump
        
        config :inspect_method, 'inspect', :long => :method, :short => :m    # The inspection method
        
        # Dumps the object to io using obj.inspect
        def dump(obj, io)
          io.puts obj.send(inspect_method)
        end
      end
    end
  end
end
require 'tap/tasks/load'

module Tap
  module Tasks
    class Load
      
      # :startdoc::task loads data as YAML
      #
      # Loads data from the input IO as YAML.
      #
      #   % tap run -- load/yaml "{key: value}" --: dump/yaml
      #   --- 
      #   key: value
      #
      class Yaml < Load
        
        config :stream, false, &c.flag   # Load documents from a stream
        
        # Loads data from io as YAML.
        def load(io)
          if stream
            load_stream(io)
          else
            YAML.load(io)
          end
        end
        
        def load_stream(io)          
          lines = []
          while !io.eof?
            line = io.readline

            if line =~ /^---/ && !lines.empty?
              io.pos = io.pos - line.length
              break
            else
              lines << line
            end
          end

          YAML.load(lines.join)
        end
        
        def complete?(io, last)
          !stream || io.eof?
        end
        
      end
    end
  end
end
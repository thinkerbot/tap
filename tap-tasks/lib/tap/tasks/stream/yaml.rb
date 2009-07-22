require 'tap/tasks/stream'

module Tap
  module Tasks
    class Stream
      
      # :startdoc::task streams data as YAML
      #
      # Stream loads data from the input IO as YAML.
      #
      class Yaml < Stream
        
        # Streams data from io as YAML.
        def load(io)          
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
        
      end
    end
  end
end
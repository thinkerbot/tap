module Tap
  module Support
    class Summary
      def initialize
        @map = []
        @width = 0
      end
      
      def add(key, env, map)
        unless map.empty?
          @map << [key, env, map]
          map.keys.each {|key| @width = key.length if @width < key.length }
        end
      end
      
      def lines
        lines = []
        @map.each do |(env_lookup, env, map)|
          lines <<  "=== #{env_lookup} (#{env.root.root})" if @map.length > 1
          map.to_a.sort_by {|(key, path)| key }.each do |(key, path)|
            desc = block_given? ? yield(path) : ''
            desc = "  # #{desc}" unless desc.empty?
            lines << ("  %-#{@width}s%s" % [key, desc])
          end
        end
        lines
      end
    end
  end
end
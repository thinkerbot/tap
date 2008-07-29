module Tap
  module Support
    class Summary
      def initialize
        @map = []
        @width = 10
      end
      
      def add(env_key, env, map)
        unless map.empty?
          @map << [env_key, env, map]
          map.each {|(key, path)| @width = key.length if @width < key.length }
        end
      end
      
      def lines
        lines = []
        @map.each do |(env_lookup, env, map)|
          lines <<  "#{env_lookup}:" if @map.length > 1
          map.each do |(key, path)|
            desc = block_given? ? (yield(path) || '') : ''
            desc = "  # #{desc}" unless desc.empty?
            lines << ("  %-#{@width}s%s" % [key, desc])
          end
        end
        lines
      end
    end
  end
end
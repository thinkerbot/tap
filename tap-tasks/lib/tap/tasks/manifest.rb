require 'tap/tasks/dump'

module Tap
  module Tasks
    # :startdoc::task
    #
    class Manifest < Dump
      config :all, false, :short => :a, &c.flag
      
      def call(input)
        process manifest(*input)
      end
      
      def manifest(*filters)
        constants = app.env.constants
        
        keys = constants.keys.collect! do |key|
          value = constants[key].require_paths.sort.join(', ')
          [key, value]
        end
        
        filters.collect! do |filter|
          Regexp.new(filter)
        end
        
        method_name = all ? :all? : :any?
        keys = keys.select do |(key, value)|
          filters.send(method_name) do |filter|
            key =~ filter || value =~ filter
          end
        end
        
        max = keys.collect {|(key, value)| key.length }.max
        keys.collect! {|entry| "%-#{max}s: %s" % entry }.sort!
        keys.join("\n")
      end
    end 
  end
end
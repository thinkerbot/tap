require 'tap/tasks/dump'

module Tap
  module Tasks
    # :startdoc::task
    #
    class Manifest < Dump 
      def process
        super(manifest)
      end
      
      def manifest
        constants = app.env.constants
        
        keys = constants.keys.sort
        max = keys.collect {|key| key.length }.max

        keys.collect! do |key|
          value = constants[key].require_paths.sort.join(', ')
          "%-#{max}s: %s" % [key, value]
        end

        keys.join("\n")
      end
    end 
  end
end
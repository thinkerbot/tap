require 'tap/tasks/dump'

module Tap
  module Tasks
    # :startdoc::task
    #
    class Manifest < Dump
      def process(input)
        super manifest(*input)
      end
      
      def manifest(filter=nil)
        constants = app.env.constants
        
        keys = constants.keys.collect! do |key|
          value = constants[key].require_paths.sort.join(', ')
          [key, value]
        end
        
        if filter
          filter = Regexp.new(filter)
          keys = keys.select {|(key, value)| key =~ filter || value =~ filter }
        end
        
        max = keys.collect {|(key, value)| key.length }.max
        keys.collect! {|entry| "%-#{max}s: %s" % entry }.sort!
        keys.join("\n")
      end
    end 
  end
end
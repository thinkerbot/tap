require 'tap/tasks/load/yaml'

module Tap
  module Tasks
    class Load
      # ::task
      class Workflow < Yaml
      
        config :resources, Tap::Env.instance, :duplicate_default => false, &c.api(:[])
        
        def load(io)
          schema = Schema.new(super(io))
         
          schema.resolve! do |type, id|
            resources[type][id]
          end
          
          schema.build!(app)
        end
      end
    end
  end
end
require 'tap/controllers/data'

module Tap
  module Controllers
    class Schema < Data
      
      # Adds to the specified schema.  Parameters:
      #
      # tasks[]:: The specified task ids are added to the schema
      # queue[]:: Queues with empty inputs are added for the task ids
      # middleware[]:: Middleware by the specified ids are added
      #
      # Joins are a bit more complicated.  A join is added if inputs
      # and outputs are specified.
      #
      # inputs[]::  An array inputs to a join
      # outputs[]:: An array outputs for a join
      # join:: The join id, 'join' if unspecified
      #
      def add(id)
        if id == "new"
          id = data.next_id(type).to_s
        end
        
        update_schema(id) do |schema|
          # tasks[]
          if tasks = request['tasks']
            tasks.each do |task|
              key = 0
              key += 1 while schema.tasks.has_key?(key.to_s)
              schema.tasks[key.to_s] = {'id' => task}
            end
          end
          
          # inputs[] outputs[] join
          inputs = request['inputs'] || []
          outputs = request['outputs'] || []
          if !inputs.empty? && !outputs.empty?
            schema.joins << [inputs, outputs, {'id' => request['join'] || 'join'}]
          end
          
          # queue[]
          if queue = request['queue']
            queue.each do |key|
              schema.queue << [key, []]
            end
          end
          
          # middleware[]
          if middleware = request['middleware']
            middleware.each do |middleware|
              schema.middleware << {'id' => middleware}
            end
          end
        end
        
        redirect uri(id)
      end
      
      # Removes tasks or joins from a schema.  Parameters:
      #
      # tasks[]:: An array of task keys to remove.
      # joins[]:: An array of join indicies to remove.
      # queue[]:: An array of queue indicies to remove.
      # middleware[]:: An array of middleware indicies to remove.
      #
      def remove(id)
        if id == "new"
          id = data.next_id(type).to_s
        end
        
        tasks = request['tasks'] || []
        joins = request['joins'] || []
        queue = request['queue'] || []
        middleware = request['middleware'] || []
        
        update_schema(id) do |schema|
          tasks.each {|key| schema.tasks.delete(key) }
          
          joins.each {|index| schema.joins[index.to_i] = nil }
          schema.joins.compact!
          
          queue.each {|index| schema.queue[index.to_i] = nil }
          schema.queue.compact!
          
          middleware.each {|index| schema.middleware[index.to_i] = nil }
          schema.middleware.compact!
          
          schema.cleanup!
        end
    
        redirect uri(id)
      end
      
      def save(id)
        if id == "new"
          id = data.next_id(type).to_s
        end
        
        data.create_or_update(type, id) do |io| 
          io << yamlize(request['schema'] || '')
        end
        
        redirect uri(id)
      end
      
      # Helper methods
      protected
      
      def env
        server.env
      end
      
      def type
        :schema
      end
      
      def display(id)
        schema = if path = data.find(type, id)
          Tap::Schema.load_file(path)
        else
          Tap::Schema.new
        end
        
        schema.resolve! do |type, key|
          env[type][key]
        end
        
        render "entry.erb", :locals => {
          :id => id,
          :schema => schema
        }, :layout => true
      end
      
      #########################
      # Helpers
      #########################
      
      def render_config(resource, name="")
        klass = resource[:class]
        values = resource[:config] || default_config(klass.configurations)
        
        module_render "_configs.erb", klass, 
          :locals => {
            :name => name,
            :configs => klass.configurations, 
            :values => values
          }
      end
      
      def default_config(configs)
        Configurable::DelegateHash.new(configs).to_hash
      end
      
      def format_yaml(object)
        object == nil ? "~" : YAML.dump(object)[4...-1].strip
      end
      
      def update_schema(id)        
        path = data.find(type, id) || data.create(type, id)
        schema = Tap::Schema.load_file(path)
        
        yield(schema)
        
        data.update(type, id) do |io| 
          io << schema.dump
        end
        
        id
      end
      
      def summarize(schema)
        summary = {}
        schema.tasks.each_key do |key|
          summary[key] = [[],[]]
        end

        index = 0
        join_order = []
        schema.joins.each do |inputs, outputs, join|
          join_order.concat inputs
          
          inputs.each do |key|
            summary[key][1] << index
          end

          outputs.each do |key|
            summary[key][0] << index
          end

          index += 1
        end

        summary.keys.sort_by do |key|
          join_order.index(key) || join_order.length
        end.collect do |key|
          [key, *summary[key]]
        end
      end
    end
  end
end
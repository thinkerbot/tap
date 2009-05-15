require 'tap/controllers/data'

module Tap
  module Controllers
    class Schema < Data
      
      # Adds tasks or joins to the schema.  Parameters:
      #
      # tasks[]::   An array of tasks to add to the schema.
      # inputs[]::  An array of task indicies used as inputs to a join.
      # outputs[]:: An array of task indicies used as outputs for a join.
      #
      def add(id)
        if id == "new"
          id = data.next_id(type).to_s
        end
        
        tasks = request['tasks'] || []
        inputs = request['inputs'] || []
        outputs = request['outputs'] || []
        queue = request['queue'] || []
        
        update_schema(id) do |schema|
          current = schema.tasks
          tasks.each do |task|
            key = task
            while current.has_key?(key)
              i ||= 0
              key = "#{task}_#{i}"
              i += 1
            end
            
            current[key] = {'id' => task}
          end
          
          if !inputs.empty? && !outputs.empty?
            schema.joins << [inputs, outputs]
          end
          
          queue.each do |task|
            schema.queue << [task]
          end
        end
        
        redirect uri(id)
      end
      
      # Removes tasks or joins from a schema.  Parameters:
      #
      # tasks[]:: An array of task keys to remove.
      # joins[]:: An array of join indicies to remove.
      #
      def remove(id)
        if id == "new"
          id = data.next_id(type).to_s
        end
        
        tasks = request['tasks'] || []
        joins = request['joins'] || []
        queue = request['queue'] || []
        
        update_schema(id) do |schema|
          tasks.each do |key|
            schema.tasks.delete(key)
          end
          
          joins.each {|index| schema.joins[index.to_i] = nil }
          schema.joins.compact!
          
          queue.each {|index| schema.queue[index.to_i] = nil }
          schema.queue.compact!
          
          schema.cleanup!
        end
    
        redirect uri(id)
      end
      
      def configure(id)
        if id == "new"
          id = data.next_id(type).to_s
        end
        
        schema = Tap::Schema.new(request['schema'] || {})
        schema.scrub! do |obj|
          scrub(obj['config'])
        end
        
        data.create_or_update(type, id) do |io| 
          io << schema.dump
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
        
        schema.resolve! do |type, key, data|
          env.constant_manifest(type)[key]
        end
        
        render "#{type}.erb", :locals => {
          :id => id,
          :schema => schema
        }, :layout => true
      end
      
      def help_uri(type, obj)
        server.uri("help/#{type}/#{obj[:id] || obj[:class].to_s.underscore}")
      end
      
      def stringify(obj)
        case obj
        when String, Numeric, true, false
          obj.to_s
        when Symbol, Regexp
          obj.inspect
        when nil
          '~'
        when $stdout
          'data/results.txt'
        else
          obj
        end
      end
      
      def default_config(configurable)
        configs = configurable.configurations
        Configurable::DelegateHash.new(configs).to_hash do |hash, key, value|
          hash[key.to_s] = stringify(value)
        end
      end
      
      def scrub(obj)
        case obj
        when Hash
          obj.delete_if do |key, value|
            value ? scrub(value) : true
          end
        when Array
          obj.delete_if do |value| 
            value ? scrub(value) : true
          end
        end
        
        false
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
    end
  end
end
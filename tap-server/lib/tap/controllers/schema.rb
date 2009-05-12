require 'tap/controllers/persistence'

module Tap
  module Controllers
    class Schema < Persistence
      set :default_layout, 'layout.erb'
      
      # GET /projects/id
      def show(id)
        # start a new schema
        id = persistence.next_id(:schema).to_s if id == 'new'
      
        # get an extension for exports
        extname = File.extname(id)
        id = id.chomp(extname)
        
        schema = if path = persistence.find(:schema, id)
          Tap::Schema.load_file(path)
        else
          Tap::Schema.new
        end
        
        case extname
        when '.txt'
          response.headers['Content-Type'] = 'text/plain'
          schema.dump
        when '.yml'
          response.headers['Content-Type'] = 'text/plain'
          response['Content-Disposition'] = "attachment; filename=#{id}.yml;"
          schema.dump
        else
          schema.resolve! do |type, key, data|
            env.constant_manifest(type)[key]
          end
          
          render 'schema.erb', :locals => {
            :id => id,
            :schema => schema
          }, :layout => true
        end
      end
        
      ############################################################
      # Update Methods (these are actions, but due to REST routes
      # they cannot be reached except through update)
      ############################################################
      
      # Adds tasks or joins to the schema.  Parameters:
      #
      # tasks[]::   An array of tasks to add to the schema.
      # inputs[]::  An array of task indicies used as inputs to a join.
      # outputs[]:: An array of task indicies used as outputs for a join.
      #
      def add(id)
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
        hash = scrub(request['schema']) do |value, mark|
          case value
          when "" then mark
          when /\A\"(.*)\"\z/ then $1
          else value
          end
        end

        schema = Tap::Schema.new(hash)
        persistence.update(:schema, id) do |io| 
          io << schema.dump
        end
        
        redirect uri(id)
      end
      
      protected # Helper Methods
      
      def env
        server.env
      end
      
      def type
        :schema
      end
      
      def check_id(id)
        raise "new is a reserved id" if id == "new"
        super
      end
      
      def help_uri(type, obj)
        server.uri("help/#{type}/#{obj[:id] || obj[:class].to_s.underscore}")
      end
      
      def scrub(hash, mark=Object.new, &block)
        result = {}
        hash.each_pair do |key, value|
          value = case value
          when Hash   then scrub(value, mark, &block)
          when String then yield(value, mark)
          else value
          end
          
          result[key] = value unless value == mark
        end
        result
      end
      
      def update_schema(id)
        path = persistence.find(:schema, id) || persistence.create(:schema, id)
        schema = Tap::Schema.load_file(path)
        
        yield(schema)
        
        persistence.update(:schema, id) do |io| 
          io << schema.dump
        end
      end
    end
  end
end
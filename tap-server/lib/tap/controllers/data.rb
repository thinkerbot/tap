require 'tap/controller'

module Tap
  module Controllers
    # ::controller
    class Data < Tap::Controller  
      include RestRoutes
      include Utils
      
      set :default_layout, 'layout.erb'
      set :reserved_ids, ['new']
      
      # GET /projects
      def index
        render 'index.erb', :layout => true
      end
      
      # GET /projects/id
      # GET /projects?id=id&as=
      def show(id)
        case request['as']
        when 'preview'
          response.headers['Content-Type'] = 'text/plain'
          data.read(type, id)
        
        when 'download'
          unless path = data.find(type, id)
            raise "unknown #{type}: #{id.inspect}"
          end
          
          download(path)
        else
          display(id)
        end
      end
      
      # POST /projects/id
      # POST /projects?id=id
      # POST /projects?type=
      def create(id)
        if id == "new"
          id = data.next_id(type).to_s
        else
          check_id(id)
        end
        
        data.create(type, id) {|io| io << parse_entry }
        redirect uri(id)
      end
      
      # PUT /projects/id
      # POST /projects/id?_method=put
      # POST /projects?_method=put&_action=select&id=id
      def update(id)
        data.update(type, id) {|io| io << parse_entry }
        redirect uri(id)
      end
      
      # DELETE /projects/id
      # POST /projects/id?_method=delete
      # POST /projects?_method=put&id=id
      def destroy(id)
        data.destroy(type, id)
        deselect([id])
        redirect uri
      end
      
      def upload(id=nil)
        check_id(id) if id
        
        data.import(type, request[type], id)
        redirect uri
      end
      
      def select(ids=[])
        data.cache[type] = ids
        redirect uri
      end
      
      def deselect(ids=[])
        if current = data.cache[type]
          current -= ids
        end
        redirect uri
      end
      
      # Renames id to request['name'] in the schema data.
      def rename(id)
        if new_id = request['new_id']
          check_id(new_id)
        else
          raise "no new id specified"
        end
        
        redirect data.move(type, id, new_id)
      end
      
      def duplicate(id)
        if new_id = request['new_id']
          check_id(new_id)
        end
        
        redirect data.copy(type, id, new_id || "#{id}_copy")
      end
      
      # Helper methods
      protected
      
      def type
        :data
      end
      
      def data
        server.data
      end
      
      #--
      # args remains an array, ie methods can take one or no inputs (but note
      # that if id is specified as an array, methods can receive and array of
      # ids.)
      def dispatch(route)
        action, *args = route
        
        if args.empty?
          if id = request['id']
            args << id
          end 
        else
          args = [File.join(*args)] 
        end
        
        args.unshift(action)
        super(args)
      end
      
      def display(id)
        render "entry.erb", :locals => {
          :id => id,
          :content => data.read(type, id)
        }, :layout => true
      end
      
      def parse_entry
        request[type]
      end
      
      def check_id(id)
        if self.class.get(:reserved_ids).include?(id)
          raise "reserved id: #{id.inspect}"
        end
      end
    end
  end
end
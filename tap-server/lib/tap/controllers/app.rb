require 'tap/controller'

module Tap
  module Controllers
    
    # :startdoc::controller builds and runs workflows
    class App < Tap::Controller
      include RestRoutes
      
      # GET /projects
      def index
        render 'index.erb', :layout => true
      end
  
      # GET /projects/*args
      def show(var, sig=nil)
        obj = app.obj(var)
        obj = obj.signal(sig) if sig
        
        module_render 'index.erb', obj, :locals => {:var => var, :sig => sig}, :layout => true
      end
      
      # POST /projects/*args
      def create(var, sig)
        params = request.params
        args = params['args'] || params
        sig ||= args.empty? ? nil : 'build'
        
        app.obj(var).signal(sig).call(args)
        redirect uri(var)
      end
      
      #     # PUT /projects/*args
      #     # POST /projects/*args?_method=put
      #     def update(*args)...
      # 
      #     # DELETE /projects/*args
      #     # POST /projects/*args?_method=delete
      #     def destroy(*args)...
      #
      
      def uri(var, sig=nil)
        super("#{var}/#{sig}")
      end
      
      protected
      
      def app
        server.app
      end
    end
  end
end
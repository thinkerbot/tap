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
      def show(obj, sig=nil)
        obj = app.get(obj)
        obj = obj.signal(sig) if sig
        
        module_render 'index.erb', obj, :locals => {:obj => obj, :sig => sig}, :layout => true
      end
      
      # POST /projects/*args
      def create(obj, sig)
        params = request.params
        args = params['args'] || params
        sig ||= args.empty? ? nil : 'build'
        
        signal = app.get(obj).signal(sig)
        
        # The app is likely running on a separate thread so immediately calling
        # the signal (the default) is not thread-safe.  Alternate modes are
        # provided to enque the signal, which is a safe way to go because when
        # the signal is executed it will have full control over the app.
        #
        # Thread mode is provided for long-running signals like /run.
        case params.delete('_mode')
        when 'safe'
          app.enque(signal, args)
        when 'thread'
          Thread.new { signal.call(args) }
        else
          signal.call(args)
        end
        
        redirect uri(obj)
      end
      
      #     # PUT /projects/*args
      #     # POST /projects/*args?_method=put
      #     def update(*args)...
      # 
      #     # DELETE /projects/*args
      #     # POST /projects/*args?_method=delete
      #     def destroy(*args)...
      #
      
      def uri(obj, sig=nil)
        super("#{obj}/#{sig}")
      end
      
      protected
      
      def app
        server.app
      end
    end
  end
end
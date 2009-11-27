require 'tap/controller'

module Tap
  module Controllers
    
    # :startdoc::controller builds and runs workflows
    class App < Tap::Controller
      include RestRoutes
      
      def route
        unescape(request.path_info)
      end
      
      def dispatch(route)
        if route == "/"
          return render('index.erb', :layout => true)
        end
        
        route =~ Tap::Parser::SIGNAL
        signal = app.route($1, $2)
        
        request_method = request.request_method
        case request_method
        when /GET/i
          module_render('get.erb', signal)
        when /POST/i
          result = signal.call(request.params)
          module_render('post.erb', signal, :locals => {:result => result})
        else
          error("cannot signal via: #{request_method}")
        end
      end
      
      def uri(obj, sig=nil)
        obj, sig = nil, obj unless sig
        super(obj ? "#{obj}/#{sig}" : sig)
      end
      
      def app
        server.app
      end
    end
  end
end
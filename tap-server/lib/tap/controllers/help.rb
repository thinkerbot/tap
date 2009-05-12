require 'tap/controller'

module Tap
  module Controllers
    
    # :startdoc::controller 
    class Help < Tap::Controller
      
      def index(type=nil, *args)
        if type
          const = env.constant_manifest(type)[args.join('/')]
        
          help_file = class_path('help.erb', const) || class_path('help.erb')
          render :file => help_file, :locals => {:obj => const}
        else
          render 'index.erb'
        end
      end
      
      protected
      
      def route
        blank, *args = request.path_info.split("/").collect {|arg| unescape(arg) }
        [:index, args]
      end
      
      def env
        server.env
      end
    end
  end
end

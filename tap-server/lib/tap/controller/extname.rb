module Tap
  class Controller
    
    # Add handling of extnames to controller paths.  The extname of a request
    # is chomped and stored in the extname attribute for use wherever.
    module Extname
      
      # Returns the extname for the current request, or nil if no extname
      # was specified in the paths_info.
      def extname
        @extname ||= nil
      end
      
      # Overrides route to chomp of the extname from the request path info.
      # If no extname is specified, extname will be remain nil.
      def route
        @extname = File.extname(request.path_info)
        @extname = nil if @extname.empty?
        args = super

        unless args.empty? && extname
          args.last.chomp!(extname)
        end

        args
      end
    end
  end
end
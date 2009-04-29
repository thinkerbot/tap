module Tap
  class Server
    # A special type of error used for specifiying controller errors.
    class ServerError < RuntimeError
      class << self
      
        # A helper to format a non-ServerError into a ServerError response.
        def response(err)
          new("500 #{err.class}: #{err.message}\n#{err.backtrace.join("\n")}").response
        end
      end
    
      # The error status
      attr_reader :status
    
      # Headers for the error response
      attr_reader :headers
    
      # The error response body
      attr_reader :body
  
      def initialize(body="500 Server Error", status=500, headers={'Content-Type' => 'text/plain'})
        @body = body
        @status = status
        @headers = headers
        super(body)
      end
    
      # Formats self as a rack response array (ie [status, headers, body]).
      def response
        [status, headers, [body]]
      end
    end
  end
end
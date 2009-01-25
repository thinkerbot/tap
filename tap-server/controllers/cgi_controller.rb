class CgiController < Tap::Controller
  module Utils
    module_function
    
    # Partitions the CGI and rack variables from a rack environment, and
    # returns them in a hash, keyed by :cgi and :rack, respectively.
    def cgi_attrs(rack_env)
      cgi = {}
      rack_env.each_pair do |key, value|
        cgi[key] = value unless key =~ /^rack\./
      end
      cgi
    end

    # Executes block with ENV set to the specified hash.
    # Non-string values in hash are skipped.
    def with_ENV(hash)
      current_env = {}
      ENV.each_pair {|key, value| current_env[key] = value }

      begin
        ENV.clear
        hash.each_pair {|key, value| ENV[key] = value if value.kind_of?(String)}

        yield
      ensure
        ENV.clear
        current_env.each_pair {|key, value| ENV[key] = value }
      end
    end
  end
  
  include Utils
  
  # Generates a [status, headers, body] response for the specified cgi.
  # The cgi will be run with ENV set as specified in rack_env.
  def index(req, args)
    cgi_path = args.join('/')
    unless path = env.cgis.search(cgi_path)
      raise "unknown cgi: #{cgi_path}"
    end
    
    # setup standard ios for capture
    current_input = $stdin
    current_output = $stdout

    cgi_input = req['rack.input']
    cgi_output = StringIO.new("")

    begin
      $stdin = cgi_input
      $stdout = cgi_output

      # run the cgi
      with_ENV(cgi_attrs(req.env)) { load(path) }

      # collect the headers and body from the output
      headers, body = cgi_output.string.split(/\r?\n\r?\n/, 2)

      raise "missing headers from: #{cgi_path}" if headers == nil
      body = "" if body == nil

      headers = headers.split(/\r?\n/).inject({}) do |hash, line|
        key, value = line.split(/:/, 2)
        hash[key] = value
        hash
      end

      # generate the response
      [headers.delete('Status') || 200, headers, body]

    rescue(Exception)
      # when an error occurs, return a standard cgi error with backtrace
      [500, {'Content-Type' => 'text/plain'}, %Q{#{$!.class}: #{$!.message}\n#{$!.backtrace.join("\n")}}]

    ensure
      $stdin = current_input
      $stdout = current_output
    end
  end
end
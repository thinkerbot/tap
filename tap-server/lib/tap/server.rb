require 'tap'
require 'rack'
require 'rack/mime'
require 'time'
require "#{File.dirname(__FILE__)}/../../vendor/url_encoded_pair_parser"

module Tap
  Tap::Env.manifest(:cgis) do |env|
    entries = env.root.glob(:cgi, "**/*.rb").sort_by {|path| File.basename(path) }
    Support::Manifest.intern(entries) do |manifest, path|
      "/" + manifest.env.root.relative_filepath(:cgi, path)
    end
  end
  
  # = UNDER CONSTRUCTION
  # Support for a Tap::Server, built on {Rack}[http://rack.rubyforge.org/].
  #
  #
  # Tap::Server is intended to extend a Tap::Env, but can extend any object
  # with the following interface:
  # 
  # * search(:public, path)
  # * cgis <Manifet>
  #
  class Server
    module Utils
      module_function
      
      def parse_schema(params)
        argh = pair_parse(params)

        parser = Support::Parser.new
        parser.parse(argh['nodes'] || [])
        parser.parse(argh['joins'] || [])
        parser.schema
      end
      
      # UrlEncodedPairParser.parse, but also doing the following:
      #
      # * reads io values (ie multipart-form data)
      # * keys ending in %w indicate a shellwords argument; values
      #   are parsed using shellwords and concatenated to other
      #   arguments for key
      #
      # Returns an argh.  The schema-related entries will be 'nodes' and
      # 'joins', but other entries may be present (such as 'action') that
      # dictate what gets done with the params.
      def pair_parse(params)
        pairs = {}
        params.each_pair do |key, values|
          next if key == nil
          key = key.chomp("%w") if key =~ /%w$/

          resolved_values = pairs[key] ||= []
          values.each do |value|
            value = value.respond_to?(:read) ? value.read : value
            
            # $~ indicates if key matches shellwords pattern
            if $~ 
              resolved_values.concat(Shellwords.shellwords(value))
            else 
              resolved_values << value
            end
          end
        end

        UrlEncodedPairParser.new(pairs).result   
      end
      
      # Partitions the CGI and rack variables from a rack environment, and
      # returns them in a hash, keyed by :cgi and :rack, respectively.
      def cgi_attrs(rack_env)
        rack = {}
        cgi = {}
        
        rack_env.each_pair do |key, value|
          (key =~ /^rack\./ ? rack : cgi)[key] = value
        end

        {:cgi => cgi, :rack => rack}
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
    
    # The handler for the server (ex Rack::Handler::WEBrick)
    attr_accessor :handler
    
    # The server Env
    attr_accessor :env
    
    def initialize(env)
      @env = env
    end
    
    # The default error template used by response
    # when an error occurs.
    DEFAULT_ERROR_TEMPLATE = %Q{
<html>
<body>
# Error handling request: <%= error.message %></br>
# <%= error.backtrace.join("<br/># ") %>

<code><pre>
<%= cgi.to_yaml %>
<%= rack.to_yaml %>
</pre></code>
</body>
</html>     
}
    
    # The {Rack}[http://rack.rubyforge.org/doc/] interface method.  Call
    # routesrequests (with preference) to:
    # * static pages
    # * cgi scripts
    # * default responses
    #
    # === Static pages
    # Static pages may be served from any env in self.  A static page is
    # served if a file with the request path exists under the 'public'
    # directory for any env.
    #
    # Envs are searched in order, using the Env#search_path method.
    #
    # === CGI scripts
    # Like static pages, cgi scripts may be served from any env in self.  
    # Scripts are discovered using a search of the cgi manifest.  See
    # cgi_response for more details.
    #
    # === Default responses
    # The default response is path-dependent:
    # 
    #   path            action
    #   /, /index       render the manifest.
    #   all others      render a 404 response
    #
    # The manifest may be refreshed by setting a query string:
    # 
    #   /?refresh=true
    #   /index?refresh=true
    #
    def call(rack_env)
      path = rack_env['PATH_INFO']
      
      case 
      when static_path = env.search(:public, path) {|file| File.file?(file) }
        # serve named static pages
        file_response(static_path, rack_env)
 
      when cgi_path = env.cgis.search(path)
        # serve cgis
        cgi_response(cgi_path, rack_env)
        
      # when task_path = tasks.search(path)
      #   # serve tasks
      #   task_response(task_path, rack_env)
        
      when path == "/" || path == "/index"
        # serve up the homepage
        if rack_env["QUERY_STRING"] == "refresh=true"
          # reset(:cgis) do |key, path|
          #   Support::Lazydoc[path].resolved = false
          # end
        end
        render_response('index.erb', rack_env)
        
      else
        # handle all other requests as errors
        render_response('404.erb', rack_env)
        
      end
    end
    
    # Creates a [status, headers, body] response using the result of the
    # block as the body.  The status and headers the defaults for 
    # {Rack::Response}[http://rack.rubyforge.org/doc/classes/Rack/Response.html].
    # If an error occurs, a default error message is generated using the
    # DEFAULT_ERROR_TEMPLATE.
    def response(rack_env)
      res = Rack::Response.new
      res.write begin
        yield(res)
      rescue
        # perhaps rescue a special type of error that
        # specifies the template it should render...
        template(DEFAULT_ERROR_TEMPLATE, cgi_attrs(rack_env).merge(:error => $!))
      end
      res.finish
    end
    
    # Generates a [status, headers, body] response for the specified file.
    # Patterned after {Rack::File#._call}[http://rack.rubyforge.org/doc/classes/Rack/File.html].
    def file_response(path, rack_env)
      response(rack_env) do |res|
        content = File.read(path)
        res.headers.merge!(
          "Last-Modified" => File.mtime(path).httpdate,
          "Content-Type" => Rack::Mime.mime_type(File.extname(path), 'text/plain'), 
          "Content-Length" => content.size.to_s)
        
        content
      end
    end

    # Generates a [status, headers, body] response for the specified cgi.
    # The cgi will be run with ENV set as specified in rack_env.
    def cgi_response(cgi_path, rack_env)
      
      # setup standard ios for capture
      current_input = $stdin
      current_output = $stdout
      
      cgi_input = rack_env['rack.input']
      cgi_output = StringIO.new("")

      begin
        $stdin = cgi_input
        $stdout = cgi_output
        
        # run the cgi
        with_ENV(rack_env) { load(cgi_path) }

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
    
    # Generates a [status, headers, body] response using the first existing
    # template matching path (as determined by Env#search_path) and the
    # specified rack_env.
    def render_response(path, rack_env)
      response(rack_env) do 
        env.render(:template, path, cgi_attrs(rack_env))
      end
    end
  end
end
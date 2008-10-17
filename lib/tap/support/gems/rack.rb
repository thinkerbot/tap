require 'rack'
require 'yaml'

# in a future release, it looks like this will be changed
require 'rack/file'
#require 'rack/mime'

module Tap
  module Support
    module Gems
      
      Tap::Env.manifest(:cgis) do |env|
        entries = []
        env.root.glob(:cgi, "**/*.rb").each do |path|
          env.root.relative_filepath(:cgi, path)
        end
        
        entries = entries.sort_by {|path| File.basename(path) }
        Support::Manifest.intern(entries) {|path| "/" + path }
      end
      
      # = UNDER CONSTRUCTION
      # Support for a Tap::Server, built on {Rack}[http://rack.rubyforge.org/].
      #
      # Tap::Support::Gems::Rack is intended to extend a Tap::Env
      module Rack
        
        # The handler for the server (ex Rack::Handler::WEBrick)
        attr_accessor :handler
        
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

        # Creates a [status, headers, body] response using the result of the
        # block as the body.  The status and headers the defaults for 
        # {Rack::Response}[http://rack.rubyforge.org/doc/classes/Rack/Response.html].
        # If an error occurs, a default error message is generated using the
        # DEFAULT_ERROR_TEMPLATE.
        def response(rack_env)
          ::Rack::Response.new.finish do |res|
            res.write begin
              yield(res)
            rescue
              template(DEFAULT_ERROR_TEMPLATE, env_attrs(rack_env).merge(:error => $!))
            end
          end
        end
        
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
          when static_path = search_path(:public, path) {|file| File.file?(file) }
            # serve named static pages
            file_response(static_path, rack_env)
            
          when cgi_path = search(:cgis, path)
            # serve cgis
            cgi_response(cgi_path, rack_env)
            
          # when task_path = search(:tasks, path)
          #   # serve tasks
          #   cgi_response('task', rack_env)
            
          when path == "/" || path == "/index"
            # serve up the homepage
            if rack_env["QUERY_STRING"] == "refresh=true"
              reset(:cgis) do |key, path|
                Support::Lazydoc[path].resolved = false
              end
            end
            render_response('index.erb', rack_env)
            
          else
            # handle all other requests as errors
            render_response('404.erb', rack_env)
            
          end
        end
        
        # Generates a [status, headers, body] response for the specified file.
        # Patterned after {Rack::File#._call}[http://rack.rubyforge.org/doc/classes/Rack/File.html].
        def file_response(path, rack_env)
          response(rack_env) do |res|
            content = File.read(path)
            res.headers.merge!(
              "Last-Modified" => File.mtime(path).httpdate,
              "Content-Type" => ::Rack::File::MIME_TYPES[File.extname(path)] || "text/plain", # Rack::Mime.mime_type(File.extname(path), 'text/plain'), 
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
        
        # def cgi_template(name, attributes={})
        #   path = root.filepath(:template, "#{name}.erb")
        #   Templater.new( File.read(path), {:server => self}.merge(attributes) ).build
        # end
        
        # Generates a [status, headers, body] response using the first existing
        # template matching path (as determined by Env#search_path) and the
        # specified rack_env.
        def render_response(path, rack_env)
          # partition and sort the env variables into
          # cgi and rack variables.
          rack, cgi = rack_env.to_a.partition do |(key, value)|
            key =~ /^rack/
          end.collect do |part|
            part.sort_by do |key, value|
              key
            end.inject({}) do |hash, (key,value)|
              hash[key] = value
              hash
            end
          end
          
          response(rack_env) do 
            render(path, env_attrs(rack_env))
          end
        end
        
        module Render
          def renderer(path)
            template = env.search_path(:template, path) {|file| File.file?(file) }
            raise("no such template: #{path}") if template == nil
            Tap::Support::Templater.new(File.read(template), marshal_dump).extend(Render)
          end
          
          def render(path, attrs={})
            renderer(path).build(attrs)
          end
        end
        
        # Builds the specified template using the rack_env and additional
        # attributes. The rack_env is partitioned into rack-related and 
        # cgi-related hashes (all rack_env entries where the key starts
        # with 'rack' are rack-related, the others are cgi-related).
        #
        # The template is built with the following standard locals:
        #
        #   server   self
        #   cgi      the cgi-related hash
        #   rack     the rack-related hash
        #
        # Plus the attributes.
        def render(path, attributes={}) # :nodoc:
          path = search_path(:template, path) {|file| File.file?(file) }
          raise("no such template: #{path}") if path == nil

          template(File.read(path) , attributes)
        end
        
        def env_attrs(rack_env)
          # partition and sort the env variables into
          # cgi and rack variables.
          rack, cgi = rack_env.to_a.partition do |(key, value)|
            key =~ /^rack/
          end.collect do |part|
            part.sort_by do |key, value|
              key
            end.inject({}) do |hash, (key,value)|
              hash[key] = value
              hash
            end
          end
          
          {:env => self, :cgi => cgi, :rack => rack}
        end
        
        def template(template, attributes={}) # :nodoc:
          Templater.new(template, attributes).extend(Render).build
        end
        
        protected
        
        # Executes block with ENV set to the specified hash.
        # Non-string values in hash are skipped.
        def with_ENV(hash) # :nodoc:
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
    end
  end
end
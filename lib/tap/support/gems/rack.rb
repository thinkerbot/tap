require 'rack'
require 'cgi'

module Tap
  module Support
    module Gems
      
      Tap::Env.manifest(:cgis, "cgi") do |search_path|
        Dir.glob(File.join(search_path, "**/*.rb")).collect do |path|
          ["/" + Tap::Root.relative_filepath(search_path, path), path]
        end
      end
      
      module Rack
        
        attr_accessor :handler
        
        def call(env)
          path = env['PATH_INFO']
          
          case 
          when public_page = known_path(:public, path)
            # serve named static pages
            response(env) { File.read(public_page) }
            
          when cgi_page = search(:cgis, path)
            # serve cgis relative to a cgi path
            run_cgi(cgi_page, env)

          when path == "/" || path == "/index"
            # serve up the homepage
            if env["QUERY_STRING"] == "refresh=true"
              reset(:cgis) do |key, path|
                Support::Lazydoc[path].resolved = false
              end
            end
            template_response('index', env)
            
          when config[:development] && template_page = known_path(:template, path)
            response(env) { template(File.read(template_page), env) }
            
          else
            # handle all other requests as errors
            template_response('404', env)
            
          end
        end
        
        def known_path(dir, path)
          each do |env|
            directory = env.root.filepath(dir)
            file = env.root.filepath(dir, path)
            
            if file != directory && file.index(directory) == 0 && File.exists?(file)
              return file
            end
          end
          
          nil
        end

        #--
        # Runs a cgi and returns an array as demanded by rack.
        def run_cgi(cgi_path, env)
          current_input = $stdin
          current_output = $stdout
          
          cgi_input = env['rack.input']
          cgi_output = StringIO.new("")

          begin
            $stdin = cgi_input
            $stdout = cgi_output

            with_env(env) { load(cgi_path) }

            # collect the headers and body from the cgi output
            headers, body = cgi_output.string.split(/\r?\n\r?\n/, 2)

            raise "missing headers from: #{cgi_path}" if headers == nil
            body = "" if body == nil

            headers = headers.split(/\r?\n/).inject({}) do |hash, line|
              key, value = line.split(/:/, 2)
              hash[key] = value
              hash
            end

            [headers.delete('Status') || 200, headers, body]
          rescue(Exception)
            # when an error occurs, return a standard cgi error with backtrace
            [500, {'Content-Type' => 'text/plain'}, %Q{#{$!.class}: #{$!.message}\n#{$!.backtrace.join("\n")}}]
          ensure
            $stdin = current_input
            $stdout = current_output
          end
        end

        # Executes block with ENV set to the specified hash.  Non-string env variables are not set.
        def with_env(env)
          current_env = {}
          ENV.each_pair {|key, value| current_env[key] = value }

          begin
            ENV.clear
            env.each_pair {|key, value| ENV[key] = value if value.kind_of?(String)}
             
            yield
          ensure
            ENV.clear
            current_env.each_pair {|key, value| ENV[key] = value }
          end
        end

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

        def response(env)
          ::Rack::Response.new.finish do |res|
            res.write begin
              yield(res)
            rescue
              template(DEFAULT_ERROR_TEMPLATE, env, :error => $!)
            end
          end
        end
        
        def cgi_template(name, attributes={})
          path = root.filepath(:template, "#{name}.erb")
          Templater.new( File.read(path), {:server => self}.merge(attributes) ).build
        end

        def template(template, env, attributes={})
          # partition and sort the env variables into
          # cgi and rack variables.
          rack, cgi = env.to_a.partition do |(key, value)|
            key =~ /^rack/
          end.collect do |part|
            part.sort_by do |key, value|
              key
            end.inject({}) do |hash, (key,value)|
              hash[key] = value
              hash
            end
          end

          Templater.new( template , {:server => self, :env => env, :cgi => cgi, :rack => rack}.merge(attributes) ).build
        end
        
        def template_response(name, env)
          path = known_path(:template, "#{name}.erb")
          response(env) { template(File.read(path), env) }
        end
      end
    end
  end
end
require 'rack'
require 'rack/mime'
require 'time'

require 'cgi'
require "#{File.dirname(__FILE__)}/../../vendor/url_encoded_pair_parser"

module Tap  
  class Controller
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
    end
    
    class << self
      def call(env)
        # route the path
        env['PATH_INFO'] =~ /^\/([^\/]+)/
        action = $1 || default_action
        unless public_instance_methods.include?(action)
          action = unknown_action
        end
        
        # handle the request
        req = Rack::Request.new(env)
        res = Rack::Response.new
        res.write new(req, res).send(action)
        res.finish
      end
      
      # Returns the method called when no action is specified,
      # by default :index.
      def default_action
        @default_action ||= 'index'
      end
      
      # Sets default_action.
      def set_default_action(input)
        @default_action = input
      end
      
      # Returns the method called when an action is unknown,
      # by default :unknown.
      def unknown_action
        @unknown_action ||= 'unknown'
      end
      
      # Sets unknown_action.
      def set_unknown_action(input)
        @unknown_action = input
      end
    end
    
    attr_reader :env
    
    def initialize(req, res)
      @req = req
      @res = res
      @env = req.env['tap.server'].env
    end
    
    def unknown
      path_info = @req.path_info
      
      case
      # when path = server.env.search(:views, path_info)
      #   # serve templates
      #   server.render(path)
        
      when path = @env.search(:public, path_info) {|file| File.file?(file) }
        
        # serve static pages
        content = File.read(path)
        @res.headers.merge!(
          "Last-Modified" => File.mtime(path).httpdate,
          "Content-Type" => Rack::Mime.mime_type(File.extname(path), 'text/plain'), 
          "Content-Length" => content.size.to_s)
          
        content
        
      else
        # missing page
        render '404.erb', :locals => {:req => @req}
      end
    end
    
    protected
    
    # TODO -- develop to echo rails/merb
    # render(thing=nil, options={})
    def render(path, options={})
      template_path = @env.search(:views, path.to_s) {|file| File.file?(file) }
      unless template_path 
        raise "no such template: #{path}"
      end
      
      render_erb File.read(template_path), options
    end
    
    def render_erb(template, options)
      require 'erb' unless defined? ::ERB
      
      instance = ::ERB.new(template)
      locals = options[:locals] || {}
      locals_assigns = locals.to_a.collect { |k,v| "#{k} = locals[:#{k}]" }
      src = "#{locals_assigns.join("\n")}\n#{instance.src}"
      eval src, binding, '(__ERB__)', locals_assigns.length + 1
      instance.result(binding)
    end
  end
end
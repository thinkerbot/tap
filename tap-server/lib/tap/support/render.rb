module Tap
  module Support
    module Render
      
      def default_layout()
      end
      
      def render(thing=nil, options={})
        # currently only erb...
        path = case File.extname(thing) 
        when '' then "#{thing}.erb"
        when '.erb' then thing
        else raise ArgumentError, "currently render can only render .erb"
        end
        
        # lookup the template path
        unless File.exists?(path)
          path = env.search(:views, path, true) {|file| File.file?(file)}
        end
        
        unless path
          raise ArgumentError, "no such thing: #{thing.inspect}"
        end
        
        locals = options[:locals] || {}
        if locals.has_key?(:env) || locals.has_key?('env')
          raise ArgumentError, "locals specifies env"
        end

        templater = Support::Templater.new(File.read(path), locals).extend Render
        templater.env = env
        content = templater.build
        
        layout = options[:layout]
        layout = default_layout if layout == nil || layout == true
        layout ? render(layout, :locals => {:content => content}, :layout => false) : content
      end
      
    end
  end
end
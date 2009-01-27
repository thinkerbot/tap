module Tap
  module Support
    module Render
      
      def render(thing=nil, options={})
        # currently only erb...
        view_path = case File.extname(thing) 
        when '' then "#{thing}.erb"
        when '.erb' then thing
        else raise ArgumentError, "currently render can only render .erb"
        end
        
        unless path = env.search(:views, view_path, true) {|file| File.file?(file) }
          raise ArgumentError, "no such thing: #{thing.inspect}"
        end
        
        locals = options[:locals] || {}
        if locals.has_key?(:env) || locals.has_key?('env')
          raise ArgumentError, "locals specifies env"
        end

        templater = Support::Templater.new(File.read(path), locals).extend Render
        templater.env = env
        templater.build
      end
      
    end
  end
end
require 'tap/env/manifest'
require 'tap/env/constant'

module Tap
  class Env
    
    #--
    # Implementation note:
    #
    # Note that the scanned constants are NOT cached in Documents.  Documents
    # track constant attributes at a global level to ensure all attributes from
    # all files are properly associated with one constant.  This works fine
    # if a constant attribute is only declared once.  In environments, and 
    # contexts where Roots get used, there are potentially several places a
    # constant attribute will be defined (ex when multiple versions declare
    # the same constant).  Hence the attribute value is not added to the
    # Lazydoc environment.
    #
    class ConstantManifest < Manifest
      
      attr_accessor :const_attr
      
      def initialize(env, const_attr)
        super(env)
        @const_attr = const_attr
      end
      
      def scan(dir, path)
        return if cache.has_key?(path)
        
        # determine the default constant name for the path;
        # this is used when no const_name is specified for
        # a constant attribute
        default_const_name = Root::Utils.relative_path(dir, path).chomp(File.extname(path)).camelize
        
        # scan for all constant attributes
        const_names = {}
        Lazydoc::Document.scan(File.read(path), "[a-z]+") do |const_name, key, value|
          const_name = default_const_name if const_name.empty?
          
          attributes = const_names[const_name] ||= {}
          attributes[key] = value
        end
        
        # store any const_names that were found,
        # or nil if none were found
        cache[path] = const_names.empty? ? nil : const_names
      end
      
      def constants(path)
        unless const_names = cache[path]
          raise "no scan for: #{path}"
        end
        
        entries = []
        const_names.each_pair do |const_name, attrs|
          attrs.each_pair do |key, value|
            if const_attr == nil || const_attr === key
              entries << Constant.new(const_name, path, value)
            end
          end
        end
        entries
      end
      
      SUMMARY_TEMPLATE = %Q{#{'-' * 80}
<%= (env_key + ':').ljust(width) %> (<%= env_path %>)
<% entries.each do |key, const| %>
  <%= key.ljust(width-2) %> # (<%= const.const_name %>) <%= const.comment %>
<% end %>
}

      def summarize
        inspect(SUMMARY_TEMPLATE, :width => 10) do |templater, globals|
          env_key = templater.env_key
          env_path = templater.env.path
          manifest = templater.manifest
          entries = manifest.minimap
          width = globals[:width]

          # determine width
          width = env_key.length if width < env_key.length
          entries.collect! do |key, const|
            width = key.length if width < key.length
            [key, const]
          end
          globals[:width] = width

          # assign locals
          templater.entries = entries
          templater.env_path = Root::Utils.relative_path(Dir.pwd, env.path) || env.path
        end
      end
      
      # Creates a new instance of self, assigned with env.
      def another(env)
        self.class.new(env, const_attr)
      end
      
    end
  end
end
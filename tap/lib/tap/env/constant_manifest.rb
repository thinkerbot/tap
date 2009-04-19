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
      
      def initialize(env, type, const_attr=type, &builder)
        super(env, type, &builder)
        @const_attr = const_attr
      end
      
      def cache
        env.cache[:constant_cache] ||= {}
      end
      
      def build
        builder.call(env).each do |dir, path|
          unless cache.has_key?(path)
            cache[path] = scan(dir, path)
          end
          
          constants(path).each do |const|
            env.register(type, const)
          end
        end if builder
        @built = true
      end
      
      def scan(dir, path)
        # determine the default constant name for the path;
        # this is used when no const_name is specified for
        # a constant attribute
        default_const_name = Root::Utils.relative_path(dir, path).chomp(File.extname(path)).camelize
        
        # note: the default const name has to be set here to allow for implicit
        # constant attributes (because a dir is needed to figure the relative path).
        # A conflict could arise if the same path is globed from two different
        # dirs... no surefire solution.
        document = Lazydoc[path]
        case document.default_const_name
        when nil then document.default_const_name = default_const_name
        when default_const_name
        else raise "found a conflicting default const name"
        end
        
        # scan for all constant attributes
        const_names = {}
        Lazydoc::Document.scan(File.read(path), "[a-z]+") do |const_name, key, value|
          if const_name.empty?
            const_name = default_const_name
          end
          
          attributes = const_names[const_name] ||= {}
          attributes[key] = value
        end
        
        const_names.empty? ? nil : const_names
      end
      
      def constants(path)
        unless cache.has_key?(path)
          raise "no scan for: #{path}"
        end
        
        unless const_names = cache[path]
          return [] 
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
      
      def [](key)
        constant = seek(key)
        constant ? constant.constantize : nil
      end
      
      SUMMARY_TEMPLATE = %Q{<% unless entries.empty? %>
#{'-' * 80}
<%= (env_key + ':').ljust(width) %> (<%= env_path %>)
<% entries.each do |key, const| %>
  <%= key.ljust(width-2) %> (<%= const.require_path %>)
<% end %>
<% end %>}

      def summarize(template=SUMMARY_TEMPLATE)
        inspect(template, :width => 10) do |templater, globals|
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
          templater.env_path = env_path
        end
      end
      
      # Creates a new instance of self, assigned with env.
      def another(env)
        self.class.new(env, type, const_attr, &builder)
      end
    end
  end
end
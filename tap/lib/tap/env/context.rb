module Tap
  class Env
    
    # Context instances track information shared by a set of Env instances, for
    # instance cached manifest data.  Caching cross-env data in a shared space
    # simplifies managment of this data, especially when dumping and loading it
    # from a static file.
    #
    # Contexts also ensure that only one env in initialized to a given
    # directory (at least among envs that share the same context). This
    # prevents errors that arise when one env eventually nests itself.
    class Context
      
      # A hash of cached manifest data
      attr_reader :cache
      
      # The config file basename
      attr_reader :basename
      
      # An array of Env instances registered with self
      attr_reader :instances
      
      # Initializes a new Context.  Options can specify a cache or a basename.
      def initialize(options={})
        options = {
          :cache => {},
          :basename => nil
        }.merge(options)
        
        @cache = options[:cache]
        @basename = options[:basename]
        @instances = []
      end
      
      # Registers env with self by adding env to instances.  Raises an error
      # if instances contains an env with the same root directory.
      def register(env)
        path = env.root.root
        
        if instance(path)
          raise "context already has an env for: #{path}"
        end
        
        instances << env
        self
      end
      
      # Gets the instance for the directory currently in instances, or nil
      # if such an instance does not exist.
      def instance(dir)
        instances.find {|env| env.root.root == dir }
      end
      
      # Returns the config filepath for the directory (ie basename under dir).
      # If basename is nil, then config_file always return nil.
      def config_file(dir)
        basename ? File.join(dir, basename) : nil
      end
    end
  end
end
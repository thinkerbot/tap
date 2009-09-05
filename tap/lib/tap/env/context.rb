module Tap
  class Env
    
    
    # Envs utilize a Context to track information shared by a set of Env
    # instances, for instance cached manifest data.  Caching data in a shared
    # space optimizes performance under normal circumstances, and facilitates
    # loading manifests from a manifest file.
    #
    # Contexts also ensure only one env in initialized to a given directory
    # (at least among envs that share the same context). This prevents errors
    # that arise when one env eventually nests itself.
    #
    class Context
      attr_reader :cache
      
      attr_reader :basename
      
      attr_reader :instances
      
      def initialize(options={})
        options = {
          :cache => {},
          :basename => Env::CONFIG_FILE
        }.merge(options)
        
        @cache = options[:cache]
        @basename = options[:basename]
        @instances = []
      end
      
      def register(env)
        path = env.root.root
        
        if instance(path)
          raise "context already has an env for: #{path}"
        end
        
        instances << env
        self
      end
      
      # gets the instance for the path currently in instances, or nil
      # if such an instance does not exist.
      def instance(path)
        instances.find {|env| env.root.root == path }
      end
      
      def config_file(path)
        basename ? File.join(path, basename) : nil
      end
      
    end
  end
end
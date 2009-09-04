module Tap
  class Env
    class Context
      attr_reader :registry
      
      attr_reader :instances
      
      attr_reader :basename
      
      attr_reader :manifests
      
      def initialize(options={})
        options = {
          :registry => {},
          :basename => Env::CONFIG_FILE
        }.merge(options)
        
        @registry = options[:registry]
        @instances = []
        @manifests = {}
        @basename = options[:basename]
      end
      
      def register(env)
        path = env.root.root
        
        if instance(path)
          raise "context already has an env for: #{path}"
        end
        
        instances << env
        self
      end
      
      def cache(env)
        registry[env.root.root] ||= {}
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
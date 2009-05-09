require 'tap/task'

module Tap
  module Tasks
    # :startdoc::task
    class Describe < Tap::Task
      
      def process(klass)
        desc = {}
        
        # Documentation
        if klass.respond_to?(:lazydoc)
          doc = {}
          
          klass.lazydoc.resolve
          Lazydoc::Document[klass.to_s].each_pair do |key, comment|
            doc[key] = resolve(comment)
          end
          
          desc[:doc] = doc
        end
        
        # Configurables
        if klass.included_modules.include?(Configurable)
          configs = {}
          
          klass.configurations.each do |name, config|
            attributes = {}
            config.attributes.each_pair do |key, value|
              attributes[key] = resolve(value)
            end
            
            configs[name] = {
              :default => resolve(config.default), 
              :attributes => attributes
            }
          end
          
          desc[:configs] = configs
        end
        
        # Inheritance
        inheritance = []
        current = klass
        while current != Object
          inheritance << current.to_s
          current = current.superclass
        end
        inheritance << 'Object'
        desc[:inheritance] = inheritance
        
        desc
      end
      
      def resolve(obj)
        case obj
        when Lazydoc::Comment
          obj.resolve
          {:summary => obj.to_s, :content => obj.comment}
        when IO
          
          case obj
          when $stdin  then '$stdin'.to_sym
          when $stdout then '$stdout'.to_sym
          when $stderr then '$stderr'.to_sym
          else
            obj
          end
          
        else
          obj
        end
      end
    end
  end
end
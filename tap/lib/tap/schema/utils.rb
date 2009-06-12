module Tap
  class Schema
    module Utils
      module_function
      
      def instantiate(data, app)
        case data
        when Hash  then data[:class].instantiate(data, app)
        when Array then data.shift.parse!(data, app)
        else raise "cannot instantiate: #{data.inspect}"
        end
      end
      
      def resolved?(data)
        case data
        when Hash  then data[:class].respond_to?(:instantiate)
        when Array then data[0].respond_to?(:parse!)
        else false
        end
      end
      
      def resolve(data)
        return data if resolved?(data)
        
        case data
        when Hash
          unless resolved?(data)
            data = symbolize(data)
            data[:class] = yield(data[:id]) || data[:id]
          end
        when Array 
          data[0] = yield(data[0]) || data[0]
        end
        
        data
      end
      
      # Symbolizes the keys of hash.  Returns non-hash values directly and
      # raises an error in the event of a symbolize conflict.
      def symbolize(hash)
        result = {}
        hash.each_pair do |key, value|
          key = key.to_sym || key
          
          if result.has_key?(key)
            raise "symbolize conflict: #{hash.inspect} (#{key.inspect})"
          end
          
          result[key] = value
        end
        result
      end
      
    end
  end
end
module Tap
  class Schema
    module Utils
      module_function
      
      def instantiate(data, app)
        data = data.dup
        
        case data
        when Hash  then data[:class].instantiate(data, app)
        when Array then data.shift.parse!(data, app)
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
        data = symbolize(data)
        return data if resolved?(data)
        
        case data
        when Hash
          data[:class] = yield(data[:id], data)
        when Array 
          data[0] = yield(data[0], data)
        end
        
        data
      end
      
      # Symbolizes the keys of hash.  Returns non-hash values directly and
      # raises an error in the event of a symbolize conflict.
      def symbolize(hash)
        return hash unless hash.kind_of?(Hash)
        
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
      
      # Returns the values for hash sorted by key.  Returns non-hash objects
      # directly.
      def dehashify(obj)
        case obj
        when nil   then []
        when Hash  then obj.keys.sort.collect {|key| obj[key] }
        else obj
        end
      end
      
      # Returns obj as a hash, using the index of each element as the 
      # key for the element.  The object must respond to each.  Returns
      # hashes directly.
      def hashify(obj)
        case obj
        when nil  then {}
        when Hash then obj
        else
          index = 0
          hash = {}
          obj.each do |entry|
            hash[index] = entry
            index += 1
          end
          hash
        end
      end
      
    end
  end
end
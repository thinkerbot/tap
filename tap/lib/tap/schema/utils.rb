module Tap
  class Schema
    module Utils
      module_function
      
      def resolve(data, dereferences)
        data = symbolize(data, dereferences)
        
        case data
        when Array
          unless data[0].respond_to?(:parse!)
            data[0] = yield(data[0], data)
          end
        when Hash 
          unless data[:class].respond_to?(:instantiate)
            data[:class] = yield(data[:id], data)
          end
          
          if config = data[:config]
            data[:config] = symbolize(config, dereferences)
          end
        else
          raise "cannot normalize: #{data.inspect}"
        end
        
        data
      end
      
      def instantiate(data, app)
        case data
        when Array then data.shift.parse!(data, app)
        when Hash  then data[:class].instantiate(data, app)
        else raise "cannot instantiate: #{data.inspect}"
        end
      end
      
      def instantiable?(data)
        case data
        when Array then data[0].respond_to?(:parse!)
        when Hash  then data[:class].respond_to?(:instantiate)
        else false
        end
      end
      
      # Symbolizes the keys of hash.  Returns non-hash values directly and
      # raises an error in the event of a symbolize conflict.  Deferences
      # are a hash of (ref, value) pairs.
      def symbolize(hash, dereferences={})
        return hash unless hash.kind_of?(Hash)
        
        result = {}
        hash.each_pair do |key, value|
          if key.kind_of?(String) && key[0] == ?@
            value = dereferences[value]
            key = key[1..-1]
          end
          
          key = key.to_sym || key
          if result.has_key?(key)
            raise "symbolize conflict: #{hash.inspect} (#{key.inspect})"
          end
          
          result[key] = value
        end
        result
      end
      
      # References are a hash of (value, ref) pairs.
      def stringify(hash, references={})
        return hash unless hash.kind_of?(Hash)
        
        result = {}
        hash.each_pair do |key, value|
          if ref = references[value]
            value = ref
            key = "@#{key}"
          end
          
          key = key.to_s
          if result.has_key?(key)
            raise "stringify conflict: #{hash.inspect} (#{key.inspect})"
          end
          
          result[key] = value
        end
        result
      end
      
      # Returns the values for hash sorted by key.  Returns non-hash objects
      # directly.
      def dehashify(hash)
        return hash unless hash.kind_of?(Hash)
        
        hash.keys.sort.collect do |key|
          hash[key]
        end
      end
      
      # Returns obj as a hash, using the index of each element as the 
      # key for the element.  The object must respond to each.  Returns
      # hashes directly.
      def hashify(obj)
        return obj if obj.kind_of?(Hash)
        
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
module Tap
  class Schema
    module Utils
      
      def instantiate(data, app)
        data = symbolize(data)

        case data
        when Array then data.shift.parse!(data, app)
        when Hash  then data[:class].instantiate(data, app)
        else raise "cannot instantiate: #{data.inspect}"
        end
      end
      
      # Symbolizes the keys of hash.  Returns non-hash values directly and
      # raises an error in the event of a symbolize conflict.
      def symbolize(hash)
        return hash unless hash.kind_of?(Hash)
        
        symbolic = {}
        hash.each_pair do |key, value|
          if key.kind_of?(String) && key[0] == ?@
            value = dereference(value)
            key = key[1..-1]
          end
          
          key = key.to_sym || key
          if symbolic.has_key?(key)
            raise "symbolize conflict: #{hash.inspect} (#{key.inspect})"
          end
          
          symbolic[key] = value
        end
        symbolic
      end
      
      def stringify(hash)
        return hash unless hash.kind_of?(Hash)
        
        stringific = {}
        hash.each_pair do |key, value|
          if ref = reference(value)
            value = ref
            key = "@#{key}"
          end
          
          key = key.to_s
          if stringific.has_key?(key)
            raise "stringify conflict: #{hash.inspect} (#{key.inspect})"
          end
          
          stringific[key] = value
        end
        stringific
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
      
      def reference(value)
        references.each_pair do |key, ref|
          return key if ref[] == value
        end
        nil
      end
      
      def dereference(key)
        references[key][]
      end
    end
  end
end
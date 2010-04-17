module Tap
  module Test
    class Env
      def path(type)
        [File.expand_path(type.to_s)]
      end
      
      def constant(const_str, type=nil)
        return const_str if const_str.kind_of?(Module)
        
        begin
          current = Object
          const_str.split(/::/).each do |const_name|
            current = current.const_get(const_name)
          end
          current
        rescue(NameError)
          raise "uninitialized constant: #{const_str.inspect}"
        end
      end
    end
  end
end
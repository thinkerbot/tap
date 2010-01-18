module Tap
  class App
    class Env
      def key(constant)
        constant.to_s
      end
      
      def get(key)
        return key if key.kind_of?(Module)
        
        begin
          current = Object
          key.split(/::/).each do |const_name|
            current = current.const_get(const_name)
          end
          current
        rescue(NameError)
          nil
        end
      end
      
      def set(*constants)
        self
      end
      
      def path(type)
        [File.expand_path(type.to_s)]
      end
    end
  end
end
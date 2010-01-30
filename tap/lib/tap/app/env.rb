module Tap
  class App
    class Env
      def path(type)
        [File.expand_path(type.to_s)]
      end
      
      def get(const_str)
        return const_str if const_str.kind_of?(Module)
        
        begin
          current = Object
          const_str.split(/::/).each do |const_name|
            current = current.const_get(const_name)
          end
          current
        rescue(NameError)
          nil
        end
      end
      
      def set(constant)
        self
      end
    end
  end
end
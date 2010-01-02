module Tap
  class App
    class Env
      def resolve(key)
        return key if key.kind_of?(Class)
        
        begin
          key.split(/::/).inject(Object) {|const, name| const.const_get(name) }
        rescue(NameError)
          nil
        end
      end
      
      def unresolve(constant)
        constant.to_s
      end
    end
  end
end
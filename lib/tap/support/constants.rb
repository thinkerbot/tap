module Tap
  module Support
    
    # Under Construction
    module Constants
      def underscore
        self.gsub(/::/, '/').
        gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
        gsub(/([a-z\d])([A-Z])/,'\1_\2').
        tr("-", "_").
        downcase
      end

      def camelize(first_letter = :upper)
        case first_letter
        when :upper then self.to_s.gsub(/\/(.?)/) { "::" + $1.upcase }.gsub(/(^|_)(.)/) { $2.upcase }
        when :lower then self.first + camelize[1..-1]
        end
      end

      def constantize
        case RUBY_VERSION
        when /^1.9/

          # a check is necessary to maintain the 1.8 behavior  
          # of lookup_const in 1.9, where ancestor constants 
          # may be returned by a direct evaluation
          const_name.split("::").inject(Object) do |current, const|
            const = const.to_sym

            current.const_get(const).tap do |c|
              unless current.const_defined?(const, false)
                raise NameError.new("uninitialized constant #{const_name}") 
              end
            end
          end

        else 
          Object.module_eval("::#{const_name}", __FILE__, __LINE__)
        end
      end

      def try_constantize
        begin
          constantize  
        rescue(NameError)
          error_name = $!.name.to_s 
          missing_const = const_name.split(/::/).inject(Object) do |current, const|
            if current.const_defined?(const) 
              current.const_get(const) 
            else 
              break(const)
            end
          end

          # check that the error_name is the first missing constant
          raise $! unless missing_const == error_name
          yield(const_name)
        end
      end

      def constants_split
        camel_cased_word = camelize
        unless /\A(?:::)?([A-Z]\w*(?:::[A-Z]\w*)*)\z/ =~ camel_cased_word
          raise NameError, "#{camel_cased_word.inspect} is not a valid constant name!"
        end

        constants = $1.split(/::/)
        current = Object
        while !constants.empty?
          break unless current.const_defined?(constants[0])
          current = current.const_get(constants.shift)
        end

        [current, constants]
      end

      protected

      def const_name
        unless /\A(?:::)?([A-Z]\w*(?:::[A-Z]\w*)*)\z/ =~ self
          raise NameError, "#{inspect} is not a valid constant name!"
        end
        $1
      end
      
    end
  end
end
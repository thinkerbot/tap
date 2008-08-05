module Tap
  module Support
    
    # ConstantUtils provides methods for transforming strings into constants.
    # Several methods are directly taken from or based heavily on the
    # ActiveSupport {Inflections}[http://api.rubyonrails.org/classes/ActiveSupport/CoreExtensions/String/Inflections.html]
    # module and should not cause conflicts if ActiveSupport is loaded
    # alongside Tap.
    #
    # ActiveSupport is distributed with an MIT-LICENSE:
    #
    #   Copyright (c) 2004-2008 David Heinemeier Hansson
    # 
    #   Permission is hereby granted, free of charge, to any person obtaining a copy of this software and 
    #   associated documentation files (the "Software"), to deal in the Software without restriction, 
    #   including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, 
    #   and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, 
    #   subject to the following conditions:
    # 
    #   The above copyright notice and this permission notice shall be included in all copies or substantial 
    #   portions of the Software.
    # 
    #   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT 
    #   LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN 
    #   NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, 
    #   WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE 
    #   SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    #
    module ConstantUtils
      
      # camelize converts self to UpperCamelCase. If the argument to 
      # camelize is set to :lower then camelize produces lowerCamelCase.
      # camelize will also convert '/' to '::' which is useful for
      # converting paths to namespaces.
      def camelize(first_letter = :upper)
        case first_letter
        when :upper then self.to_s.gsub(/\/(.?)/) { "::" + $1.upcase }.gsub(/(^|_)(.)/) { $2.upcase }
        when :lower then self.first + camelize[1..-1]
        end
      end
      
      # The reverse of camelize. Makes an underscored, lowercase form 
      # from self.  underscore will also change '::' to '/' to convert 
      # namespaces to paths.
      def underscore
        self.gsub(/::/, '/').
        gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
        gsub(/([a-z\d])([A-Z])/,'\1_\2').
        tr("-", "_").
        downcase
      end
      
      # constantize tries to find a declared constant with the name specified 
      # by self. It raises a NameError when the name is not in CamelCase 
      # or is not initialized.  
      def constantize
        case RUBY_VERSION
        when /^1.9/

          # a check is necessary to maintain the 1.8 behavior  
          # in 1.9, where ancestor constants may be returned 
          # by a direct evaluation
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
      
      # Tries to constantize self; if a NameError is raised, try_constantize
      # passes control to the block.  Control is only passed if the NameError
      # is for one of the constants in self.
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
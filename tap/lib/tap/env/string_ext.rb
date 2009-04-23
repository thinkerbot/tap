module Tap
  class Env
    
    # StringExt provides two common string transformations, camelize and
    # underscore. StringExt is automatically included in String.
    #
    # Both methods are directly taken from the ActiveSupport {Inflections}[http://api.rubyonrails.org/classes/ActiveSupport/CoreExtensions/String/Inflections.html]
    # module.  StringExt should not cause conflicts if ActiveSupport is
    # loaded alongside Tap.
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
    module StringExt
      
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
      
    end
  end
end

class String # :nodoc:
  include Tap::Env::StringExt
end
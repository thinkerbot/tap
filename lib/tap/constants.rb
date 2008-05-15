module Tap
  MAJOR = 0
  MINOR = 9
  TINY = 2
  
  VERSION="#{MAJOR}.#{MINOR}.#{TINY}" 
  WEBSITE="http://tap.rubyforge.org"
  
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
      unless /\A(?:::)?([A-Z]\w*(?:::[A-Z]\w*)*)\z/ =~ self
        raise NameError, "#{camel_cased_word.inspect} is not a valid constant name!"
      end

      Object.module_eval("::#{$1}", __FILE__, __LINE__)
    end
    
    def try_constantize
      begin
        constantize  
      rescue(NameError)
        yield 
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
  end
end
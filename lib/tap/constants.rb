module Tap
  MAJOR = 0
  MINOR = 9
  TINY = 2
  
  VERSION="#{MAJOR}.#{MINOR}.#{TINY}" 
  WEBSITE="http://tap.rubyforge.org"
  
  # Under Construction
  module Constants
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
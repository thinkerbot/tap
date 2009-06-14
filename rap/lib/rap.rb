require 'tap'
require 'rap/declarations'

module Rap
  autoload(:Rake, 'rap/rake')

  MAJOR = 0
  MINOR = 14
  TINY = 0
  
  VERSION="#{MAJOR}.#{MINOR}.#{TINY}"
  WEBSITE="http://tap.rubyforge.org/rap"
end
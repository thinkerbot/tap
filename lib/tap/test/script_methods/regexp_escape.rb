module Tap
  module Test
    module ScriptMethods
      class RegexpEscape < Regexp
        BASIC_ESCAPE = Regexp.quote(":...:")
        SUBSTITUENT_ESCAPE = /:\.\(.*\)\.:/
        
        class << self
          def resolve(str)
            substituents = []
            str.scan(SUBSTITUENT_ESCAPE) do
              substituents << $&[3...-3]
            end

            str.split(SUBSTITUENT_ESCAPE).collect do |split|
              Regexp.quote(split).gsub(BASIC_ESCAPE, ".*?")
            end.zip(substituents).flatten.join
          end
        end
        
        def initialize(str)
          super(RegexpEscape.resolve(str))
          @original_str = str
        end
          
        def to_s
          @original_str
        end
      end
    end
  end
end
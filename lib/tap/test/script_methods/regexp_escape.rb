require 'tap/test/utils'

module Tap
  module Test
    module ScriptMethods
      
      # RegexpEscape is a subclass of regexp that escapes all but the text in a
      # special escape sequence.  This allows the creation of complex regexps
      # to match, for instance, console output.
      #
      # The RegexpEscape.escape (or equivalently the quote) method does the
      # work; all regexp-active characters are escaped except for characters
      # enclosed by ':.' and '.:' delimiters.
      #
      #   RegexpEscape.escape('reg[exp]+ chars. are(quoted)')       # => 'reg\[exp\]\+\ chars\.\ are\(quoted\)'
      #   RegexpEscape.escape('these are not: :.a(b*)c.:')          # => 'these\ are\ not:\ a(b*)c'
      #
      # In addition, all-period regexps are automatically upgraded to '.*?';
      # use the '.{n}' notation to specify n arbitrary characters.
      #
      #   RegexpEscape.escape('_:..:_:...:_:....:')        # => '_.*?_.*?_.*?'
      #   RegexpEscape.escape(':..{1}.:')                  # => '.{1}'
      #
      # RegexpEscape instances are initialized using the escaped input string
      # and format the original string upon to_s, to simplify their use in 
      # tests.
      #
      #   r = RegexpEscape.new %q{
      #   a multiline
      #   :...:
      #   example}
      #
      #   r =~ %q{
      #   a multiline
      #   matching
      #   example}  # => true
      #
      #   r !~ %q{
      #   a failing multiline
      #   example}  # => true
      #
      #   r.to_s 
      #   # => %q{\n
      #   # a multiline\n
      #   # :...:\n
      #   # example}
      #
      class RegexpEscape < Regexp
        
        # matches the escape sequence
        ESCAPE_SEQUENCE = /:\..*?\.:/
        
        class << self
        
          # Escapes regexp-active characters in str, except for character
          # delimited by ':.' and '.:'.  See the class description for
          # details.
          def escape(str)
            substituents = []
            str.scan(ESCAPE_SEQUENCE) do
              regexp_str = $&[2...-2]
              regexp_str = ".*?" if regexp_str =~ /^\.*$/
              substituents << regexp_str
            end

            splits = str.split(ESCAPE_SEQUENCE).collect do |split|
              super(split)
            end
            splits << "" if splits.empty?
            splits.zip(substituents).flatten.join
          end
          
          # Same as escape.
          def quote(str)
            escape(str)
          end
        end
        
        def initialize(str)
          super(RegexpEscape.escape(str))
          @original_str = str
        end
        
        # Returns the original string for self, but with
        # whitespace escaped as in Utils#whitespace_escape
        def to_s
          Utils.whitespace_escape(@original_str)
        end
      end
    end
  end
end
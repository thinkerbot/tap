module Tap
  module Test
    module ShellTest
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
      # and return the original string upon to_s.
      #
      #   str = %q{
      #   a multiline
      #   :...:
      #   example}
      #   r = RegexpEscape.new(str)
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
      #   r.to_s    # => str
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
            substituents << ""

            splits = str.split(ESCAPE_SEQUENCE).collect do |split|
              super(split)
            end
            splits << "" if splits.empty?
          
            splits.zip(substituents).to_a.flatten.join
          end
        
          # Same as escape.
          def quote(str)
            escape(str)
          end
        end
      
        # Generates a new RegexpEscape by escaping the str, using the same
        # options as Regexp.
        def initialize(str, *options)
          super(RegexpEscape.escape(str), *options)
          @original_str = str
        end
      
        # Returns the original string for self
        def to_s
          @original_str
        end
      end
    end
  end
end
autoload(:Shellwords, 'shellwords')

module Tap
  
  # A parser for workflows defined on the command line.
  class Parser
    class << self
      def parse(argv=ARGV)
        parse!(argv.dup)
      end
      
      def parse!(argv=ARGV)
        argv = shellsplit(argv) if argv.kind_of?(String)
        return nil if argv.empty?
        
        sig, obj = argv.shift, nil
        
        if sig =~ OBJECT
          obj, sig = $1, $2
        end
        
        {'obj' => obj, 'sig' => sig, 'args' => argv}
      end
      
      def shellsplit(line, comment="#")
        words = []
        field = ''
        line.scan(/\G\s*(?>([^\s\\\'\"]+)|'([^\']*)'|"((?:[^\"\\]|\\.)*)"|(\\.?)|(\S))(\s|\z)?/m) do
          |word, sq, dq, esc, garbage, sep|
          raise ArgumentError, "Unmatched double quote: #{line.inspect}" if garbage
          break if word == comment
          field << (word || sq || (dq || esc).gsub(/\\(?=.)/, ''))
          if sep
            words << field
            field = ''
          end
        end
        words
      end
      
      def each_signal(io)
        offset = -1 * ($/.length + 1)
        
        carryover = nil
        io.each_line do |line|
          if line[offset] == ?\\
            carryover ||= []
            carryover << line[0, line.length + offset]
            carryover << $/
            next
          end
          
          if carryover
            carryover << line
            line = carryover.join
            carryover = nil
          end
          
          signal = parse!(line)
          yield(signal) if signal
        end
      end
    end
    
    # The escape begin argument
    ESCAPE_BEGIN = "-."

    # The escape end argument
    ESCAPE_END = ".-"

    # The parser end flag
    END_FLAG = "---"
  
    # Matches any breaking arg. Examples:
    #
    #   --
    #   --:
    #   --[1,2][3]
    #   --@
    #   --/var
    #   --.
    #
    # After the match:
    #
    #   $1:: The string after the break, or nil
    #        (ex: '--' => nil, '--:' => ':', '--[1,2][3,4]' => '[1,2][3,4]')
    #
    BREAK =  /\A--(?:\z|([\:\[\/\.@].*?)\z)/
  
    # The node modifier.
    NODE_BREAK = nil
  
    # The join modifier.
    JOIN_BREAK = "."
  
    # Matches a sequence break. After the match:
    #
    #   $1:: The modifier string, or nil
    #        (ex: ':' => nil, ':i' => 'i')
    #
    SEQUENCE = /\A:(.+)?\z/
  
    # Matches a generic join break. After the match:
    #
    #   $1:: The inputs string.
    #        (ex: '[1,2,3][4,5,6]' => '1,2,3')
    #   $2:: The outputs string.
    #        (ex: '[1,2,3][4,5,6]' => '4,5,6')
    #   $3:: The modifier string, or nil
    #        (ex: '[][]is' => 'is')
    #
    JOIN = /\A\[(.*?)\]\[(.*?)\](.+)?\z/
  
    # Matches a join modifier. After the match:
    #
    #   $1:: The modifier flag string.
    #        (ex: 'is.sync' => 'is')
    #   $2:: The class string.
    #        (ex: 'is.sync' => 'sync')
    #
    JOIN_MODIFIER = /\A([A-z]*)(?:\.(.*))?\z/
  
    # Matches an enque modifier. After the match:
    #
    #   $1:: The modifier string, or nil
    #        (ex: '@var' => 'var')
    #
    ENQUE = /\A@(.+)?\z/
    
    # Matches a signal break. After the match:
    #
    #   $1:: The object string, or nil
    #        (ex: 'obj/sig' => 'obj')
    #   $2:: The signal string
    #        (ex: 'obj/sig' => 'sig')
    #
    SIGNAL = /\A\/(?:(.*)\/)?(.*)\z/
    
    # Splits a signal into an object string and a signal string.  If OBJECT
    # doesn't match, then the string can be considered a signal, and the
    # object is nil. After a match:
    #
    #   $1:: The object string
    #        (ex: 'obj/sig' => 'obj')
    #   $2:: The signal string
    #        (ex: 'obj/sig' => 'sig')
    #
    OBJECT = /\A(.*)\/(.*)\z/
    
    attr_reader :specs
    
    def initialize(specs=[])
      @specs = specs
    end
    
    def parse(argv)
      argv = argv.dup unless argv.kind_of?(String)
      parse!(argv)
    end

    # Same as parse, but removes parsed args from argv.
    def parse!(argv)
      argv = Shellwords.shellwords(argv) if argv.kind_of?(String)
      return argv if argv.empty?
      
      unless argv[0] =~ BREAK
        argv.unshift("--") 
      end
      
      @current_type = nil
      @current_index = -1
      @current = nil
      escape = false
      
      while !argv.empty?
        arg = argv.shift

        # if escaping, add escaped arguments 
        # until an escape-end argument
        if escape
          if arg == ESCAPE_END
            escape = false
          else
            current << arg
          end
          next
        end
      
        # handle breaks and parser flags
        case arg
        when BREAK
          begin
            @current_type = nil
            @current_index += 1
            @current = parse_break($1)
          rescue
            raise "invalid break: #{arg} (#{$!.message})"
          end
          next

        when ESCAPE_BEGIN
          escape = true
          next

        when END_FLAG
          break
        
        end if arg[0] == ?-
      
        # add all remaining args to the current argv
        current << arg
      end
      
      @current_type = nil
      @current_index = nil
      @current = nil
      
      argv
    end
    
    private
    
    def spec(*argv) # :nodoc:
      specs << argv
      argv
    end
    
    # returns the current argv or a new spec argv for the current type/index
    def current # :nodoc:
      @current ||= spec(@current_type, nil, 'set', @current_index.to_s)
    end
  
    # determines the type of break and modifies self appropriately
    def parse_break(one) # :nodoc:
      case one
      when NODE_BREAK
        set_type(:node)
      when JOIN_BREAK
        set_type(:join)
      when SEQUENCE
        parse_sequence($1)
      when JOIN
        parse_join($1, $2, $3)
      when ENQUE
        parse_enque($1)
      when SIGNAL
        parse_signal($1, $2)
      else
        raise "invalid modifier"
      end
    end
    
    # sets the type of the next spec
    def set_type(type) # :nodoc:
      @current_type = type
      nil
    end
    
    # parses the match of a SEQUENCE regexp
    def parse_sequence(one) # :nodoc:
      unless @current_index > 0
        raise "no prior entry"
      end
      
      @current_type = :node
      @current = nil
      argv = current
      parse_join_spec(one, "#{@current_index - 1}", @current_index.to_s)
      argv
    end
    
    # parses the match of a JOIN regexp
    def parse_join(one, two, three) # :nodoc:
      parse_join_spec(three, one, two)
    end
    
    # parses a join modifier string into an argv.
    def parse_join_spec(modifier, inputs, outputs) # :nodoc:
      argv = [:join, nil, 'set', nil]
      
      case 
      when modifier.nil?
        argv << '/tap/join'
        argv << inputs
        argv << outputs
      when modifier =~ JOIN_MODIFIER
        argv << ($2 || 'join')
        argv << inputs
        argv << outputs
        $1.split("").each {|char| argv << "-#{char}"}
      else
        raise "invalid join modifier"
      end
      
      specs << argv
      argv
    end
    
    # parses the match of an ENQUE regexp
    def parse_enque(one) # :nodoc:
      spec(:signal, nil, 'enque', one)
    end
    
    # parses the match of a SIGNAL regexp
    def parse_signal(one, two) # :nodoc:
      spec(:signal, one, two)
    end
  end
end
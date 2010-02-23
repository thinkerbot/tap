require 'tap/join'
require 'tap/tasks/sig'

module Tap
  
  # A parser for workflows defined on the command line.
  class Parser
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
    BREAK = /\A-(-|-?[\:\/].*)?\z/
  
    # The node modifier.
    NODE = nil
    
    ENQUE_NODE = '-'
    
    # Matches a sequence break. After the match:
    #
    #   $1:: The modifier string, or nil
    #        (ex: ':' => nil, ':i' => 'i')
    #
    SEQUENCE = /\A(-)?:(.+)?\z/
  
    # Matches a join modifier. After the match:
    #
    #   $1:: The modifier flag string.
    #        (ex: 'is.sync' => 'is')
    #   $2:: The class string.
    #        (ex: 'is.sync' => 'sync')
    #
    MODIFIER = /\A([A-z]*)(?:\.(.*))?\z/
    
    # Matches a signal break. After the match:
    #
    #   $1:: The object string, or nil
    #        (ex: 'obj/sig' => 'obj')
    #   $2:: The signal string
    #        (ex: 'obj/sig' => 'sig')
    #
    SIGNAL = /\A(-)?\/(.*)\z/
    
    ENQUE = lambda {|app, obj, argv| app.queue.enq(obj, argv) }
    EXEC  = lambda {|app, obj, argv| app.dispatch(obj, argv) }
    
    attr_reader :specs
    
    def initialize
      @specs = []
    end
    
    def parse(argv)
      parse!(argv.dup)
    end

    # Same as parse, but removes parsed args from argv.
    def parse!(argv)
      return argv if argv.empty?
      
      unless argv[0] =~ BREAK
        argv.unshift("--") 
      end
      
      index = -1
      current = nil
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
            index += 1
            current = parse_break(index, $1)
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
      
      argv
    end
    
    def build_to(app)
      specs.each do |(type, args)|
        app.call('sig' => 'set', 'args' => args, &block(type))
      end
      
      specs.clear
      self
    end
    
    private
    
    def spec(type, *argv) # :nodoc:
      specs << [type, argv]
      argv
    end
    
    def block(type) # :nodoc:
      case type
      when :ignore then nil
      when :enque  then ENQUE
      when :exec   then EXEC
      else raise "unknown block type: #{type.inspect}"
      end
    end
    
    def parse_break(index, one) # :nodoc
      case one
      when NODE
        spec(:ignore, index.to_s)
      when ENQUE_NODE
        spec(:enque, index.to_s)
      when SEQUENCE
        parse_sequence(index, $1, $2)
      when SIGNAL
        parse_signal(index, $1, $2)
      else
        raise "invalid modifier"
      end
    end
      
    # parses the match of a SEQUENCE regexp
    def parse_sequence(index, one, two) # :nodoc:
      unless index > 0
       raise "no prior entry"
      end
      
      current = parse_break(index, one)
      argv = spec(:ignore, nil)
      
      case two
      when nil
        argv << Tap::Join
      when MODIFIER
        argv << ($2 || Tap::Join)
        $1.split("").each {|char| argv << "-#{char}"}
      else
        raise "invalid join modifier"
      end
      
      argv << (index - 1).to_s
      argv << index.to_s
      
      current
    end
    
    def parse_signal(index, one, two) # :nodoc:
      type = one.nil? ? :exec : :enque
      spec(type, index.to_s, Tap::Tasks::Sig, '--bind', two)
    end
  end
end
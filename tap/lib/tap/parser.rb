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
    BREAK =  /\A-(-)?(?:\z|([\:\/].*?)\z)/
  
    # The node modifier.
    NODE_BREAK = nil
    
    # Matches a sequence break. After the match:
    #
    #   $1:: The modifier string, or nil
    #        (ex: ':' => nil, ':i' => 'i')
    #
    SEQUENCE = /\A:(.+)?\z/
  
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
    SIGNAL = /\A\/(.*)\z/
    
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
      
      current_index = -1
      current = nil
      escape = false
      enque = []
      
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
          current_index += 1
          enque = $1.nil? ? false : true
          current = spec(enque, current_index.to_s)
          
          case $2
          when NODE_BREAK
            # nothing to do...
            
          when SEQUENCE
            unless current_index > 0
              raise "no prior entry"
            end

            seq = parse_sequence($1)
            seq << (current_index - 1).to_s
            seq << current_index.to_s
            
          when SIGNAL
            current << Tap::Tasks::Sig
            current << $1
            
          else
            raise "invalid break: #{arg}"
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
      specs.each do |(enque, args)|
        app.call('sig' => 'set', 'args' => args) do |obj, argv|
          app.enq(obj, *argv) if enque
        end
      end
      
      specs.clear
      self
    end
    
    private
    
    def spec(enque, *argv) # :nodoc:
      specs << [enque, argv]
      argv
    end
    
    # parses the match of a SEQUENCE regexp
    def parse_sequence(one) # :nodoc:
      argv = spec(false, nil)
      
      case one
      when nil
        argv << Tap::Join
      when MODIFIER
        argv << ($2 || Tap::Join)
        $1.split("").each {|char| argv << "-#{char}"}
      else
        raise "invalid join modifier"
      end
      
      argv
    end
  end
end
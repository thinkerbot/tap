require 'tap/join'
require 'tap/signal'

module Tap
  
  # A parser for workflows defined on the command line.
  class Parser
    
    BREAK = /\A-(?!-?\w)/
    
    OPTION = /\A--?\w/
    
    SET = '-'
    
    ENQUE = '--'
    
    EXECUTE = '-!'
    
    # Matches a sequence break. After the match:
    #
    #   $1:: The modifier string, or nil
    #        (ex: ':' => nil, ':i' => 'i')
    #
    JOIN = /\A-:(.+)?\z/
  
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
    SIGNAL = /\A-\/(.*)\z/
    
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
    
    # The escape begin argument
    ESCAPE_BEGIN = "-."

    # The escape end argument
    ESCAPE_END = ".-"

    # The parser end flag
    END_FLAG = "---"
    
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
      
      @current_index = -1
      current = argv[0] =~ BREAK ? nil : spec(:enque)
      escape = false
      
      while !argv.empty?
        arg = argv.shift

        # collect escaped arguments until an escape-end
        if escape
          if arg == ESCAPE_END
            escape = false
          else
            current << arg
          end
          next
        end
        
        # collect non-option/break arguments
        unless arg[0] == ?-
          current << arg
          next
        end
        
        begin
          
          # parse option/break arguments
          case arg
          when SET
            current = spec(:ignore)
          when ENQUE
            current = spec(:enque)
          when OPTION
            current << arg
          when JOIN
            current = parse_join($1)
          when SIGNAL
            current = parse_signal($1)
          when EXECUTE
            current = spec(:execute)
          when ESCAPE_BEGIN
            escape = true
          when END_FLAG
            break
          else
            raise "unknown"
          end
          
        rescue
          raise "invalid break: #{arg} (#{$!.message})"
        end
      end
      
      argv
    end
    
    def build_to(app)
      blocks = Hash.new do |hash, type|
        hash[type] = block(type, app)
      end
      
      specs.each do |(spec, type)|
        app.call(spec, &blocks[type])
      end
      
      specs.clear
      self
    end
    
    private
    
    def next_args # :nodoc:
      @current_index += 1
      [@current_index.to_s]
    end
    
    def spec(type, args=next_args) # :nodoc:
      specs << [{'sig' => 'set', 'args' => args}, type]
      args
    end
    
    def block(type, app) # :nodoc:
      case type
      when :enque
        lambda {|obj, args| app.queue.enq(obj, args) }
      when :execute
        lambda {|obj, args| app.dispatch(obj, args) }
      else
        nil
      end
    end
      
    # parses the match of a JOIN regexp
    def parse_join(one) # :nodoc:
      if @current_index < 0
        raise "no prior entry"
      end
      
      current = spec(:ignore)
      join = spec(:ignore, [nil])
      
      case one
      when nil
        join << Tap::Join
      when MODIFIER
        join << ($2 || Tap::Join)
        $1.split('').each {|flag| join << "-#{flag}"}
      else
        raise "invalid join modifier"
      end
      
      join << (@current_index - 1).to_s
      join << @current_index.to_s
      
      current
    end
    
    # parses the match of a SIGNAL regexp
    def parse_signal(one) # :nodoc:
      raise "no signal specified" if one.empty?
      
      args = next_args
      args << Tap::Signal
      
      if one =~ OBJECT
        args << $1
        args << $2
      else
        args << nil
        args << one
      end
      
      spec(:enque, args)
    end
  end
end
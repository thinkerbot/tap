require 'shellwords'

module Tap
  
  # A parser for workflow schema defined on the command line.
  #
  # == Syntax
  #
  # The command line syntax can be thought of as a series of ARGV arrays
  # connected by breaks.  The arrays define tasks in a workflow while the
  # breaks define joins and middleware.  These are the available breaks:
  #
  #   break          meaning
  #   --             default delimiter
  #   --:            sequence join
  #   --[][]         join (ex: sequence, fork, merge)
  #   --/            middleware
  #   --.            generic resource
  #
  # As an example, this defines three tasks (a, b, c) and sequences the
  # b and c tasks:
  #
  #   Schema.parse("a -- b --: c").workflow
  #   # => [
  #   # [0, "task", "a"],
  #   # [1, "task", "b"],
  #   # [2, "task", "c"],
  #   # [nil, "join", "join", [1], [2]]
  #   # ]
  #
  # ==== Escapes and End Flags
  #
  # Breaks can be escaped by enclosing them in '-.' and '.-' delimiters;
  # any number of arguments may be enclosed within the escape. After the 
  # end delimiter, breaks are active once again.
  #
  #   Schema.parse("a -. -- b .- -- c").workflow
  #   # => [
  #   # [0, "task", "a", "--", "b"],
  #   # [1, "task", "c"]
  #   # ]
  #
  # Parsing continues until the end of argv, or a an end flag '---' is 
  # reached.  The end flag may also be escaped.
  #
  #   Schema.parse("a -- b --- c").workflow
  #   # => [
  #   # [0, "task", "a"],
  #   # [1, "task", "b"]
  #   # ]
  #
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
    BREAK =  /\A--(?:\z|([\:\[\/\.@].*?)\z)/
  
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
    JOIN = /\A\[([\d,]*)\]\[([\d,]*)\](.+)?\z/
  
    # Matches a join modifier. After the match:
    #
    #   $1:: The modifier flag string.
    #        (ex: 'is.sync' => 'is')
    #   $2:: The class string.
    #        (ex: 'is.sync' => 'sync')
    #
    JOIN_MODIFIER = /\A([A-z]*)(?:\.(.*))?\z/
  
    # Matches a signal break. After the match:
    #
    #   $1:: The modifier string, or nil
    #        (ex: '/var' => 'var')
    #
    SIGNAL = /\A\/(.+)?\z/
  
    # Matches a spec break.
    SPEC = "."
    
    # Matches a job break.
    JOB = "@"
  
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
            @current_index += 1
            @current = parse_break($1)
          rescue
            raise "invalid break: #{arg.inspect} (#{$!.message})"
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
      
      @current_index = nil
      @current = nil
      
      argv
    end
    
    def build(app, auto_enque=true)
      results = specs.collect do |spec|
        if spec[1] # type
          app.build(spec)
        else
          var, type, sig, *args = spec
          app.obj(var).signal(sig, *args)
        end
      end
      
      if auto_enque
        queue = []
        deque = []
        
        results.select do |result|
          obj, args = result
          
          case obj.class.type
          when 'task' then queue << result
          when 'join' then deque.concat(obj.outputs)
          end
        end
        
        deque.uniq!
        queue.delete_if {|(node, args)| deque.include?(node) }
        app.queue.concat(queue)
      end
      
      specs.clear
      results
    end
  
    private
    
    def spec(*argv) # :nodoc:
      specs << argv
      argv
    end
    
    # returns the current argv or a task argv for the current index
    def current # :nodoc:
      @current ||= spec(@current_index.to_s, 'task')
    end
  
    # determines the type of break and modifies self appropriately
    def parse_break(one) # :nodoc:
      case one
      when nil
      when JOB
        parse_job
      when SEQUENCE
        parse_sequence($1)
      when JOIN
        parse_join($1, $2, $3)
      when SIGNAL
        parse_signal($1)
      when SPEC
        parse_spec
      else
        raise "invalid modifier"
      end
    end
    
    # parses the match of a SEQUENCE regexp
    def parse_sequence(one) # :nodoc:
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
      argv = [nil, 'join']
      
      case 
      when modifier.nil?
        argv << 'join'
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
        
    # parses the match of a SIGNAL regexp
    def parse_signal(one) # :nodoc:
      spec(one, nil)
    end
    
    def parse_spec # :nodoc:
      spec(@current_index.to_s)
    end
    
    def parse_job # :nodoc:
      spec(nil, nil, 'enque')
    end
  end
end
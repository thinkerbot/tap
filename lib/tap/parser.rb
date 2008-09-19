autoload(:Shellwords, 'shellwords')

module Tap
  class Parser
    module Utils
      module_function
      
      # Parses the input string as YAML, if the string matches the YAML document 
      # specifier (ie it begins with "---\s*\n").  Otherwise returns the string.
      #
      #   str = {'key' => 'value'}.to_yaml       # => "--- \nkey: value\n"
      #   Tap::Script.parse_yaml(str)            # => {'key' => 'value'}
      #   Tap::Script.parse_yaml("str")          # => "str"
      def parse_yaml(str)
        str =~ /\A---\s*\n/ ? YAML.load(str) : str
      end
      
      # Shell quotes the input string by enclosing in quotes if
      # str has no quotes, or double quotes if str has no double
      # quotes.  Returns the str if it has not whitespace, quotes
      # or double quotes.
      #
      # Raises an ArgumentError if str has both quotes and double
      # quotes.
      def shell_quote(str)
        return str unless str =~ /[\s'"]/
        
        quote = str.include?("'")
        double_quote = str.include?('"')
        
        case
        when !quote then "'#{str}'"
        when !double_quote then "\"#{str}\""
        else raise ArgumentError, "cannot shell quote: #{str}"
        end
      end
      
      # Defines a break regexp that matches a bracketed-pairs
      # break.  The left and right brackets are specified as
      # inputs.  After a match:
      #
      #   $2:: The source string after the break. 
      #        (ex: '--[]' => '', '--1[]' => '1')
      #   $3:: The target string. 
      #        (ex: '--[]' => '', '--1[1,2,3]' => '1,2,3')
      #   $4:: The modifier string.
      #        (ex: '--[]i' => 'i', '--1[1,2,3]is' => 'is')
      #
      def bracket_regexp(l, r)
        /\A(--)?(\d*)#{Regexp.escape(l)}([\d,]*)#{Regexp.escape(r)}([A-z]*)\z/
      end
      
      # The escape begin argument
      ESCAPE_BEGIN = "-."
      
      # The escape end argument
      ESCAPE_END = ".-"
      
      # The parser end flag
      END_FLAG = "---"
      
      # Matches any breaking arg (ex: '--', '--+', '--1:2')
      BREAK =  /\A--(\z|[\+\d\:\*\[\{\(])/
        
      # Matches the start of any workflow regex (ex: '+', '2', '[', '{')
      WORKFLOW =  /\A[\+\d\:\*\[\{\(]/

      # Matches an execution-round break.  After the match:
      #
      #   $3:: The round string after the break, or nil. 
      #        (ex: '--' => nil, '--++' => '++', '--+1' => '+1')
      #   $6:: The target string, or nil. 
      #        (ex: '--+' => nil, '--+[1,2,3]' => '1,2,3')
      #
      ROUND = /\A(--\z|(--)?(\+(\d*|\+*))(\[([\d,]*)\])?\z)/

      # Matches a sequence break.  After the match:
      #
      #   $2:: The sequence string after the break. 
      #        (ex: '--:' => ':', '--1:2' => '1:2', '--1:' => '1:', '--:2' => ':2')
      #   $4:: The modifier string.
      #        (ex: '--:i' => 'i', '--1:2is' => 'is')
      #
      SEQUENCE = /\A(--)?(\d*(:\d*)+)([A-z]*)\z/
      
      # Matches an instance break.  After the match:
      #
      #   $2:: The index string after the break.
      #        (ex: '--*' => '', '--*1' => '1')
      #
      INSTANCE = /\A(--)?\*(\d*)\z/
      
      # A break regexp using "[]"
      FORK = bracket_regexp("[", "]")
      
      # A break regexp using "{}"
      MERGE = bracket_regexp("{", "}")
      
      # A break regexp using "()"
      SYNC_MERGE = bracket_regexp("(", ")")

      # Parses an indicies str along commas, and collects the indicies
      # as integers. Ex:
      #
      #   parse_indicies('')            # => []
      #   parse_indicies('1')           # => [1]
      #   parse_indicies('1,2,3')       # => [1,2,3]
      #
      def parse_indicies(str, regexp=/,+/)
        indicies = []
        str.split(regexp).each do |n| 
          indicies << n.to_i unless n.empty?
        end
        indicies
      end

      # Parses the match of a ROUND regexp into a round index
      # and an array of task indicies that should be added to the
      # round. The inputs correspond to $3 and $6 for the match.
      #
      # If $3 is nil, a round index of zero is assumed; if $6 is  
      # nil or empty, then indicies of [:current_index] are assumed.
      #
      #   parse_round("+", "")          # => [1, [:current_index]]
      #   parse_round("+2", "1,2,3")    # => [2, [1,2,3]]
      #   parse_round(nil, nil)         # => [0, [:current_index]]
      #
      def parse_round(three, six)
        index = case three
        when nil then 0
        when /\d/ then three[1, three.length-1].to_i
        else three.length
        end
        [index, six.to_s.empty? ? [current_index] : parse_indicies(six)]
      end

      # Parses the match of a SEQUENCE regexp into an array of task
      # indicies. The input corresponds to $2 for the match.  The 
      # previous and current index are assumed if $2 starts and/or ends 
      # with a semi-colon.
      #
      #   parse_sequence("1:2:3")       # => [1,2,3]
      #   parse_sequence(":1:2:")       # => [:previous_index,1,2,:current_index]
      #
      def parse_sequence(two)
        seq = parse_indicies(two, /:+/)
        seq.unshift previous_index if two[0] == ?:
        seq << current_index if two[-1] == ?:
        seq
      end
      
      # Parses the match of an INSTANCE regexp into an index.
      # The input corresponds to $2 for the match.  The current 
      # index is assumed if $2 is empty.
      #
      #   parse_instance("1")           # => 1
      #   parse_instance("")            # => :current_index
      #
      def parse_instance(two)
        two.empty? ? current_index : two.to_i
      end

      # Parses the match of an bracket_regexp into a [source_index, 
      # target_indicies] array. The inputs corresponds to $2 and
      # $3 for the match.  The previous and current index are assumed 
      # if $2 and/or $3 is empty.
      #
      #   parse_bracket("1", "2,3")     # => [1, [2,3]]
      #   parse_bracket("", "")         # => [:previous_index, [:current_index]]
      #   parse_bracket("1", "")        # => [1, [:current_index]]
      #   parse_bracket("", "2,3")      # => [:previous_index, [2,3]]
      #
      def parse_bracket(two, three)
        targets = parse_indicies(three)
        targets << current_index if targets.empty?
        [two.empty? ? previous_index : two.to_i, targets]
      end
    end
    
    class TaskDefinition
      attr_reader :argv
      attr_reader :source
      attr_reader :join
      
      def initialize
        @argv = []
        @source = nil
        @join = nil
      end
      
      def source=(input)
        # remove the join in the targets, if
        # necessary, to prevent scrambling
        if @source.kind_of?(Join)
          @source.targets.each do |target|
            target.join = nil
          end
        end
        
        @source = input
      end
      
      def join=(input)
         @join = input
         
        # set the source of the targets
        if input.kind_of?(Join)
          input.targets.each do |target|
            target.source = input
          end
        end
      end
    end
    
    class Join
      attr_accessor :type
      attr_accessor :targets
      attr_accessor :options
      
      def initialize(type, targets, options)
        @type = type
        @targets = targets
        @options = options
      end
    end
    
    class << self  
      def load(task_argv)
        task_argv = YAML.load(task_argv) if task_argv.kind_of?(String)
        
        tasks, argv = task_argv.partition {|obj| obj.kind_of?(Array) }
        parser = new
        parser.tasks.concat(tasks)
        parser.parse(argv)
        parser
      end
    end
    
    include Utils
    
    # An array of task definitions.
    attr_reader :task_definitions
    
    def initialize(argv=nil)
      @task_definitions = []
      @current_index = 0
      
      case argv
      when String, Array 
        parse(argv)
      end
    end
    
    def clear
      @task_definitions = []
      @current_index = 0
    end
    
    def [](index)
      task_definitions[index] ||= TaskDefinition.new
    end

    # Iterates through the argv splitting out task and workflow definitions.
    # Task definitions are split out (with configurations) along round and/or
    # workflow break lines.  Rounds and workflows are dynamically parsed;
    # tasks may be reassigned to different rounds or workflows by later 
    # arguments.
    #
    # Parse is non-destructive to argv.  If a string argv is provided, parse
    # splits it into an array using Shellwords.
    #
    # ==== Round Assignment
    # Tasks can be defined and set to a round using the following:
    #
    #   break           assigns task(s)         to round
    #   --              next                    0
    #   --+             next                    1
    #   --++            next                    2
    #   --+2            next                    2
    #   --+2[1,2,3]     1,2,3                   2
    #
    # Here all task (except c) are parsed into round 0, then the
    # final argument reassigns e to round 3.
    #
    #   p = Parser.new "a -- b --+ c -- d -- e --+3[4]"
    #   p.rounds                   # => [[0,1,3],[2], nil, [4]]
    #
    # ==== Workflow Assignment
    # All simple workflow patterns except switch can be specified within
    # the parse syntax (switch is the exception because there is no good
    # way to define a block from an array).  
    #
    #   break      pattern       source(s)      target(s)
    #   --:        sequence      last           next
    #   --[]       fork          last           next
    #   --{}       merge         next           last
    #   --()       sync_merge    next           last
    #
    #   example       meaning
    #   --1:2         1.sequence(2)
    #   --1:2:3       1.sequence(2,3)
    #   --:2:         last.sequence(2,next)
    #   --[]          last.fork(next)
    #   --1{2,3,4}    1.merge(2,3,4)
    #   --(2,3,4)     last.sync_merge(2,3,4)
    #
    # Note how all of the bracketed styles behave similarly; they are
    # parsed with essentially the same code, only reversing the source
    # and target in the case of merges.
    #
    # Here a and b are sequenced inline.  Task c is assigned to no 
    # workflow until the final argument which sequenced b and c.
    #
    #   p = Parser.new "a --: b -- c --1:2i"
    #   p.argvs                    # => [["a"], ["b"], ["c"]]
    #   p.workflow(:sequence)      # => [[0,[1],''],[1,[2],'i']]
    #
    # ==== Globals
    # Global instances of task (used, for example, by dependencies) may
    # be assigned in the parse syntax as well.  The break for a global
    # is '--*'.
    #
    #   p = Parser.new "a -- b --* global_name --config for --global"
    #   p.globals                  # => [2]
    #
    # ==== Escapes and End Flags
    # Breaks can be escaped by enclosing them in '-.' and '.-' delimiters;
    # any number of arguments may be enclosed within the escape. After the 
    # end delimiter, breaks are active once again.
    #
    #   p = Parser.new "a -- b -- c"
    #   p.argvs                    # => [["a"], ["b"], ["c"]]
    # 
    #   p = Parser.new "a -. -- b .- -- c"
    #   p.argvs                    # => [["a", "--", "b"], ["c"]]
    #
    # Parsing continues until the end of argv, or a an end flag '---' is 
    # reached.  The end flag may also be escaped.
    #
    #   p = Parser.new "a -- b --- c"
    #   p.argvs                    # => [["a"], ["b"]]
    #
    #--
    # === Examples
    # Parse two tasks, with inputs and configs at separate times.  Both 
    # are assigned to round 0.
    #
    #   p = Parser.new
    #   p.parse(["a", "b", "--config", "c"])
    #   p.tasks          
    #   # => [
    #   # ["a", "b", "--config", "c"]]
    #
    #   p.parse(["x", "y", "z"])
    #   p.tasks          
    #   # => [
    #   # ["a", "b", "--config", "c"],
    #   # ["x", "y", "z"]]
    #   
    #   p.rounds         # => [[0,1]]
    #
    # Parse two simple tasks at the same time into different rounds.
    #
    #   p = Parser.new ["a", "--+", "b"]
    #   p.tasks          # => [["a"], ["b"]]
    #   p.rounds         # => [[0], [1]]
    #
    # Rounds can be declared multiple ways:
    #
    #   p = Parser.new ["--+", "a", "--", "b", "--", "c", "--", "d"]
    #   p.tasks          # => [["a"], ["b"], ["c"], ["d"]]
    #   p.rounds         # => [[1,2,3], [0]]
    #
    #   p.parse ["+3[2,3]"]
    #   p.rounds         # => [[1], [0], nil, [2,3]]
    #
    # Note the rounds were re-assigned using the second parse.  Very
    # similar things may be done with workflows (note also that this
    # example shows how parse splits a string input into an argv 
    # using Shellwords):
    #
    #   p = Parser.new "a --: b --: c --: d"
    #   p.tasks                   # => [["a"], ["b"], ["c"], ["d"]]
    #   p.workflow(:sequence)     # => [[0,1],[1,2],[2,3]]
    #
    #   p.parse "1[2,3]"
    #   p.workflow(:sequence)     # => [[0,1],[2,3]]
    #   p.workflow(:fork)         # => [[1,[2,3]]]
    #
    #   p.parse "e --{2,3}"
    #   p.tasks                   # => [["a"], ["b"], ["c"], ["d"], ["e"]]
    #   p.workflow(:sequence)     # => [[0,1]]
    #   p.workflow(:fork)         # => [[1,[2,3]]]
    #   p.workflow(:merge)        # => [[4,[2,3]]]
    #
    # Use escapes ('-.' and '.-') to bring breaks into a task array.  Any
    # number of breaks/args may occur within an escape sequence; breaks
    # are re-activated after the stop-escape:
    #
    #   p = Parser.new "a -. -- b -- .- c -- d"
    #   p.tasks                   # => [["a", "--", "b", "--", "c"], ["d"]]
    #
    # Use the stop delimiter to stop parsing (the unparsed argv is 
    # returned by parse):
    #
    #   argv = ["a", "--", "b", "---", "args", "after", "stop"]
    #   p = Parser.new
    #   p.parse(argv)             # => ["args", "after", "stop"]
    #   p.tasks                   # => [["a"], ["b"]]
    #
    def parse(argv)
      parse!(argv.kind_of?(String) ? argv : argv.dup)
    end
    
    # Same as parse, but removes parsed args from argv.
    def parse!(argv)
      if argv.kind_of?(String)
        argv = Shellwords.shellwords(argv)
      end
      argv.unshift('--')
      
      self.clear
      current_argv = self[current_index].argv
      escape = false
      while !argv.empty?
        arg = argv.shift
        
        # if escaping, add escaped arguments 
        # until an escape-end argument
        if escape
          if arg == ESCAPE_END
            escape = false
          else
            current_argv << arg
          end
          
          next
        end
        
        # begin escaping if indicated
        if arg == ESCAPE_BEGIN
          escape = true
          next
        end
        
        # break on an end-flag
        break if arg == END_FLAG

        # add all other non-breaking args to
        # the current argv; this includes
        # both inputs and configurations
        unless arg =~ BREAK || (current_argv.empty? && arg =~ WORKFLOW)
          current_argv << arg
          next  
        end
        
        # a breaking argument was reached:
        # unless the current argv is empty,
        # append and start a new definition
        unless current_argv.empty?
          self.current_index += 1
          current_argv = self[current_index].argv
        end
        
        # determine the type of break and modify
        # task definitions appropriately
        case arg
        when ROUND
          round, indicies = parse_round($3, $6)
          indicies.each {|index| self[index].source = round }
          next
          
        when SEQUENCE
          indicies = parse_sequence($2)
          while indicies.length > 1
            set(:sequence, $4, indicies.shift, indicies[0])
         end
          
        when INSTANCE    
          self[parse_instance($2)].source = :global
          
        when FORK        then set(:fork, $4, *parse_bracket($2, $3))
        when MERGE       then set(:merge, $4, *parse_bracket($2, $3))
        when SYNC_MERGE  then set(:sync_merge, $4, *parse_bracket($2, $3))
        else raise ArgumentError, "invalid break argument: #{arg}"
        end
      end

      argv
    end
    
    def argvs
      task_definitions.collect do |task_definition|
        task_definition.argv
      end.delete_if {|argv| argv.empty? }
    end
    
    # Returns an array of [type, targets] objects; the index of
    # each entry corresponds to the task on which to build the
    # workflow.
    #
    # If a type is specified, the output is ordered differently;
    # The return is an array of [source, targets] for the 
    # specified workflow type.  In this case the order of the
    # returned array is meaningless.
    #
    def workflow(type=nil)
      declarations = []
      task_definitions.each_index do |source_index|
        task_definition = task_definitions[source_index]
        next unless task_definition
        
        join = task_definition.join
        next unless join && join.type == type
        
        target_indicies = join.targets.collect {|target| task_definitions.index(target) }
        declarations << [source_index, target_indicies, join.options]  
      end
      
      declarations
    end
    
    def globals
      globals = []
      task_definitions.each_index do |index|
        globals << index if task_definitions[index].source == :global
      end
      globals
    end
    
    # Returns an array task indicies; the index of each entry
    # corresponds to the round the tasks should be assigned to.
    #
    def rounds
      rounds = []
      task_definitions.each_index do |index|
        round = task_definitions[index].source
        (rounds[round] ||= []) << index if round.kind_of?(Integer)
      end
      
      rounds.each {|round| round.uniq! unless round.nil? }
      rounds
    end
    
    def to_s
      segments = tasks.collect do |argv| 
        argv.collect {|arg| shell_quote(arg) }.join(' ')
      end
      each_round_str {|str| segments << str }
      each_workflow_str {|str| segments << str }
      
      segments.join(" -- ")
    end
    
    def dump
      segments = tasks.dup
      each_round_str {|str| segments << str }
      each_workflow_str {|str| segments << str }

      segments
    end
    
    def build(app)
      instances = []
      
      # instantiate and assign globals
      globals.each do |index|
        task, args = yield(tasks[index])
        task.class.instance = task
        instances[index] = [task, args]
      end
      
      # instantiate the remaining task classes
      tasks.each_with_index do |args, index|
        instances[index] ||= yield(args)
      end

      # build the workflow
      workflow.each_with_index do |(type, target_indicies, options), source_index|
        next if type == nil

        targets = if target_indicies.kind_of?(Array)
          target_indicies.collect {|i| instances[i][0] }
        else
          instances[target_indicies][0]
        end
        #targets << options
        
        instances[source_index][0].send(type, *targets)
      end

      # build queues
      queues = rounds.collect do |round|
        round.each do |index|
          task, args = instances[index]
          instances[index] = nil
          task.enq(*args)
        end

        app.queue.clear
      end
      queues.delete_if {|queue| queue.empty? }
      
      # notify any args that will be overlooked
      instances.compact.each do |(instance, args)|
        next if args.empty?
        puts "ignoring args: #{instance} [#{args.join(' ')}]"
      end

      queues
    end
    
    protected
    
    # Returns the index of the last argv parsed.
    attr_accessor :current_index
    
    # Returns the index of the next argv to be parsed.
    def previous_index
      raise 'there is no previous index' if current_index < 1
      current_index - 1
    end
    
    # Sets the targets to the source in workflow_map, tracking the
    # workflow type.
    def set(type, options, source_index, target_indicies) # :nodoc
      targets = [*target_indicies].collect {|target_index| self[target_index] }
      self[source_index].join = Join.new(type, targets, options)
    end
    
    # Yields each round formatted as a string.
    def each_round_str # :nodoc
      rounds.each_with_index do |indicies, round_index|
        unless indicies == nil
          yield "+#{round_index}[#{indicies.join(',')}]"
        end
      end
    end
    
    # Yields each workflow element formatted as a string.
    def each_workflow_str # :nodoc
      workflow.each_with_index do |(type, targets), source|
        next if type == nil
        
        yield case type
        when :sequence   then [source, *targets].join(":")
        when :fork       then "#{source}[#{targets.join(',')}]"
        when :merge      then "#{source}{#{targets.join(',')}}"
        when :sync_merge then "#{source}(#{targets.join(',')})"
        end
      end
    end
  end
end
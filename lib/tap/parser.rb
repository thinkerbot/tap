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
      #   $3:: The target string, or nil. 
      #        (ex: '--[]' => '', '--1[1,2,3]' => '1,2,3')
      #
      def bracket_regexp(l, r)
        /\A(--)?(\d*)#{Regexp.escape(l)}([\d,]*)#{Regexp.escape(r)}\z/
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
      #
      SEQUENCE = /\A(--)?(\d*(:\d*)+)\z/
      
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
      # nil, then indicies of [] are assumed.
      #
      #   parse_round("+", "")          # => [1, []]
      #   parse_round("+2", "1,2,3")    # => [2, [1,2,3]]
      #   parse_round(nil, nil)         # => [0, []]
      #
      def parse_round(three, six)
        index = case three
        when nil then 0
        when /\d/ then three[1, three.length-1].to_i
        else three.length
        end
        [index, six == nil ? [] : parse_indicies(six)]
      end

      # Parses the match of a SEQUENCE regexp into an array of task
      # indicies. The input corresponds to $2 for the match.  The 
      # current and next index are assumed if $2 starts and/or ends 
      # with a semi-colon.
      #
      #   parse_sequence("1:2:3")       # => [1,2,3]
      #   parse_sequence(":1:2:")       # => [:current_index,1,2,:next_index]
      #
      def parse_sequence(two)
        seq = parse_indicies(two, /:+/)
        seq.unshift current_index if two[0] == ?:
        seq << next_index if two[-1] == ?:
        seq
      end
      
      # Parses the match of an INSTANCE regexp into an index.
      # The input corresponds to $2 for the match.  The next 
      # index is assumed if $2 is empty.
      #
      #   parse_instance("1")           # => 1
      #   parse_instance("")            # => :next_index
      #
      def parse_instance(two)
        two.empty? ? next_index : two.to_i
      end

      # Parses the match of an bracket_regexp into a [source_index, 
      # target_indicies] array. The inputs corresponds to $2 and
      # $3 for the match.  The current and next index are assumed 
      # if $2 and/or $3 is empty.
      #
      #   parse_bracket("1", "2,3")     # => [1, [2,3]]
      #   parse_bracket("", "")         # => [:current_index, [:next_index]]
      #   parse_bracket("1", "")        # => [1, [:next_index]]
      #   parse_bracket("", "2,3")      # => [:current_index, [2,3]]
      #
      def parse_bracket(two, three)
        targets = parse_indicies(three)
        targets << next_index if targets.empty?
        [two.empty? ? current_index : two.to_i, targets]
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
    
    # An array of task declarations.
    attr_reader :tasks
    
    # The internal rounds data; an array of integers signifying the
    # round a task should be assigned to, at a given index.
    attr_reader :round_indicies
    
    # The internal workflow data; an array of [type, targets] pairs 
    # signifying the workflow type and targets assigned to the task 
    # at a given index.  Differs from the return from workflow in
    # that reversed-workflows (ex merge, sync_merge) will be organized
    # by target rather than by source.
    attr_reader :workflows
    
    # An array of indicies indicating which tasks are intended to
    # be global instances.
    attr_reader :globals
    
    def initialize(argv=nil)
      @tasks = []
      @round_indicies = []
      @workflows = []
      @globals = []
      
      case argv
      when String, Array 
        parse(argv)
      end
    end
    
    # Iterates through the argv splitting out task and workflow definitions.
    # Task definitions are split out (with configurations) along round and/or
    # workflow break lines.  Rounds and workflows are dynamically parsed;
    # tasks may be reassigned to rounds, or have their workflow reassigned
    # by later arguments, perhaps in later calls to parse.
    #
    # Parse is non-destructive to argv.  Parsing continues until the end of
    # argv, or a an end flag '---' is reached.  The remaining argv is
    # returned as an array.  Breaks can be escaped by enclosing them in 
    # '-.' and '.-' delimiters.
    #
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
      parse!(argv.dup)
    end
    
    # Same as parse, but removes parsed args from argv.
    def parse!(argv)
      if argv.kind_of?(String)
        argv = Shellwords.shellwords(argv)
      end
      
      round_index = 0
      current = []
      escape = false
      while !argv.empty?
        arg = argv.shift
        
        # add escaped arguments
        if escape
          if arg == ESCAPE_END
            escape = false
          else
            current << arg
          end
          
          next
        end
        
        # begin escaping if necessary
        if arg == ESCAPE_BEGIN
          escape = true
          next
        end
        
        # break if the end flag is reached
        break if arg == END_FLAG

        # add all non-breaking args to the
        # current argv array.  this should
        # include all lookups, inputs, and
        # configurations
        unless arg =~ BREAK || (current.empty? && arg =~ WORKFLOW)
          current << arg
          next  
        end
        
        # unless the current argv is empty,
        # append and start a new argv
        unless current.empty?
          add_task(current, round_index)
          round_index = 0
          current = []
        end
        
        # determine the type of break, parse, 
        # and add to the appropriate collection
        case arg
        when ROUND
          round_index, indicies = parse_round($3, $6)
          indicies.each {|index| round_indicies[index] = round_index }
          next
          
        when SEQUENCE   
          indicies = parse_sequence($2)
          while indicies.length > 1
            set_workflow(:sequence, indicies.shift, indicies[0])
          end
          
        when INSTANCE    then globals << parse_instance($2)
        when FORK        then set_workflow(:fork, *parse_bracket($2, $3))
        when MERGE       then set_reverse_workflow(:merge, *parse_bracket($2, $3))
        when SYNC_MERGE  then set_reverse_workflow(:sync_merge, *parse_bracket($2, $3))
        else raise ArgumentError, "invalid break argument: #{arg}"
        end
        
        round_index = nil
      end
      
      unless current.empty?
        add_task(current, round_index)
      end
      
      argv
    end
    
    # Returns an array of [type, targets] objects; the index of
    # each entry corresponds to the task on which to build the
    # workflow of the specified type.  
    #
    # If a type is specified, the output is ordered differently;
    # The return is an array of [source, targets] for the 
    # specified workflow type.  In this case the order of the
    # returned array is meaningless.
    #
    def workflow(type=nil)
      # recollect reverse types
      
      workflows = []
      @workflows.each_with_index do |entry, source|
        next if entry == nil
        
        workflows[source] = case entry[0]
        when :merge, :sync_merge
          workflow_type, target = entry
          (workflows[target] ||= [workflow_type, []])[1] << source
          nil
        else entry
        end
      end
      
      return workflows if type == nil
      
      declarations = []
      workflows.each_with_index do |(workflow_type, targets), source|
        declarations << [source, targets] if workflow_type == type
      end
      
      declarations
    end
    
    # Returns an array task indicies; the index of each entry
    # corresponds to the round the tasks should be assigned to.
    #
    def rounds
      collected_rounds = []
      @round_indicies.each_with_index do |round_index, index|
        (collected_rounds[round_index] ||= []) << index unless round_index == nil
      end
      
      collected_rounds.each {|round| round.uniq! unless round.nil? }
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
      # attempt lookup and instantiation of the task classes
      # note that instances is actually an array of [instance, args]
      # pairs, where the instance will be enqued with the args
      instances = tasks.collect do |args|
        yield(args)
      end
      
      # assign globals
      # globals.each do |index|
      #   task, args = instances[index]
      #   instances[index] = nil
      #   task.class.instance = task
      # end

      # build the workflow
      workflow.each_with_index do |(type, target_indicies), source_index|
        next if type == nil

        targets = if target_indicies.kind_of?(Array)
          target_indicies.collect {|i| instances[i][0] }
        else
          instances[target_indicies][0]
        end
        
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
      
      # check
      instances.compact.each do |(instance, args)|
        next if args.empty?
        puts "ignoring args: #{instance} [#{args.join(' ')}]"
      end

      queues
    end
    
    protected
    
    # Returns the index of the next argv to be parsed.
    def next_index
      tasks.length
    end
    
    # Returns the index of the last argv parsed.
    def current_index
      tasks.length - 1
    end
    
    # Sets the targets to the source in workflows, tracking the
    # workflow type.
    def set_workflow(type, source, targets) # :nodoc
      workflows[source] = [type, targets]
      [*targets].each {|target| round_indicies[target] = nil }
    end
    
    # Sets a reverse workflow... ie the source is set to
    # each target index.
    def set_reverse_workflow(type, source, targets) # :nodoc
      targets.each {|target| set_workflow(type, target, source) }
    end
    
    def add_task(definition, round_index) # :nodoc
      tasks << definition
      round_indicies[current_index] = round_index
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
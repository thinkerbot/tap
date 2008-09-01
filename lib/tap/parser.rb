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

      # Parses the match of a SEQUENCE regexp into a [source_index, 
      # target_indicies] array. The input corresponds to $2 for the 
      # match.  The current and next index are assumed if $2 starts 
      # and/or ends with a semi-colon.
      #
      #   parse_sequence("1:2:3")       # => [1, [2,3]]
      #   parse_sequence(":1:2:")       # => [:current_index, [1,2,:next_index]]
      #
      def parse_sequence(two)
        seq = parse_indicies(two, /:+/)
        seq << next_index if two[-1] == ?:
        [two[0] == ?: ? current_index : seq.shift, seq]
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
    
    include Utils
    
    attr_reader :argvs
    attr_reader :sequences
    attr_reader :instances
    attr_reader :forks
    attr_reader :merges
    attr_reader :sync_merges
    
    def initialize(argv=nil)
      @argvs = []
      @rounds = []
      @sequences = []
      @instances = []
      @forks = []
      @merges = []
      @sync_merges = []
      
      parse(argv) unless argv == nil
    end
    
    def rounds
      collected_rounds = []
      @rounds.each_with_index do |round_index, index|
        (collected_rounds[round_index] ||= []) << index unless round_index == nil
      end
      
      collected_rounds.each {|round| round.uniq! unless round.nil? }
    end
    
    def parse(argv)
      current_round_index = @rounds[next_index]
      current = []
      argv.each do |arg|
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
          @argvs << current
          @rounds[current_index] = (current_round_index || 0)
          current_round_index = @rounds[next_index]
          current = []
        end
        
        # determine the type of break, parse, 
        # and add to the appropriate collection
        case arg
        when ROUND
          current_round_index, indicies = parse_round($3, $6)
          indicies.each {|index| @rounds[index] = current_round_index }

        when SEQUENCE   then @sequences << parse_sequence($2)
        when INSTANCE   then @instances << parse_instance($2)
        when FORK       then @forks << parse_bracket($2, $3)
        when MERGE      then @merges << parse_bracket($2, $3)
        when SYNC_MERGE then @sync_merges << parse_bracket($2, $3)
        else raise ArgumentError, "invalid break argument: #{arg}"
        end
      end
      
      unless current.empty?
        @argvs << current
        @rounds[current_index] = (current_round_index || 0)
      end
    end
    
    def workflow
      [ [:sequence, @sequences],
        [:fork, @forks],
        [:merge, @merges]]
      #[:sequence, @sequences]
    end
    
    def workflow_indicies
      results = sequences.collect {|source, targets| targets } +
      forks.collect {|source, targets| targets } +
      merges.collect {|target, sources| target } +
      sync_merges.collect {|target, sources| target }
      
      results.flatten.uniq.sort
    end
    
    
    protected
    
    # Returns the index of the next argv to be parsed.
    def next_index
      argvs.length
    end
    
    # Returns the index of the last argv parsed.
    def current_index
      argvs.length - 1
    end
    
  end
end
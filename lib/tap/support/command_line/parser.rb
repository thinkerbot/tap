module Tap
  module Support
    module CommandLine
      class Parser
        class << self
          def parse_sequence(str, count=0)
             seq = []
             seq << count if str[0] == ?:
             str.split(/:+/).each do |n| 
               seq << n.to_i unless n.empty?
             end
             seq << count + 1 if str[-1] == ?:
             seq
          end
          
          def bracket_regexp(l, r)
            /\A--(\d*)#{Regexp.escape(l)}([\d,]*)#{Regexp.escape(r)}\z/
          end
          
          def parse_bracket(lead, str, count=0)
             bracket = []
             str.split(/,+/).each do |n| 
               bracket << n.to_i unless n.empty?
             end

             [lead.empty? ? count : lead.to_i, bracket]
          end
          
          # Parses the input string as YAML, if the string matches the YAML document 
          # specifier (ie it begins with "---\s*\n").  Otherwise returns the string.
          #
          #   str = {'key' => 'value'}.to_yaml       # => "--- \nkey: value\n"
          #   Tap::Script.parse_yaml(str)            # => {'key' => 'value'}
          #   Tap::Script.parse_yaml("str")          # => "str"
          def parse_yaml(str)
            str =~ /\A---\s*\n/ ? YAML.load(str) : str
          end

          def shift_arg(argv)
            index = nil
            argv.each_with_index do |arg, i|
              if arg !~ /\A-/
                index = i 
                break
              end
            end
            index == nil ? nil : argv.delete_at(index)
          end
        end
        
        ROUND = /\A--(\+(\d+)|\+*)\z/
        SEQUENCE = /\A--(\d*(:\d*)+)\z/
        FORK = bracket_regexp("[", "]")
        MERGE = bracket_regexp("{", "}")
        SYNC_MERGE = bracket_regexp("(", ")")
        INVALID =  /\A--(\z|[^A-Za-z])/
        
        attr_reader :rounds
        attr_reader :sequences
        attr_reader :forks
        attr_reader :merges
        attr_reader :sync_merges
        
        def initialize(argv)
          @sequences = []
          @forks = []
          @merges = []
          @sync_merges = []
          
          current = []
          current_round = []
          count = 0
          @rounds = [current_round]
          
          argv.each do |arg|
            unless arg =~ INVALID
              current << arg
              next
            end
            
            # for peformance split to match
            # most arguments just once.
            current_round << current unless current.empty?
            current = []

            case arg
            when ROUND
              current_round = (@rounds[$2 ? $2.to_i : $1.length] ||= [])
            when SEQUENCE
              @sequences << Parser.parse_sequence($1, count)
            when FORK
              @forks << Parser.parse_bracket($1, $2, count)
            when MERGE
              @merges << Parser.parse_bracket($1, $2, count)
            when SYNC_MERGE
              @sync_merges << Parser.parse_bracket($1, $2, count)
            else 
              raise ArgumentError, "invalid argument: #{arg}"
            end
            
            count += 1
          end
          
          current_round << current unless current.empty?
          @rounds.delete_if {|round| round.nil? || round.empty? }
        end
        
        def targets
          targets = []
          sequences.each {|sequence| targets.concat(sequence[1..-1]) }
          forks.each {|fork| targets.concat(fork[1]) }
          targets.concat merges.collect {|target, sources| target }
          targets.concat sync_merges.collect {|target, sources| target }
          
          targets.uniq.sort
        end
        
      end
    end
  end
end
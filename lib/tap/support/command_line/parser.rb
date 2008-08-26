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
      end
    end
  end
end
require 'tap/support/parsers/base'

module Tap
  module Support
    module Parsers
      class CommandLine < Base
        class << self
          def parse_sequence(str, count=0)
             seq = []
             seq << count if str[0] == ?:
             str.split(/:+/).each do |n| 
               seq << n.to_i unless n.empty?
             end
             seq << count + 1 if str[-1] == ?:
             [seq.shift, seq]
          end
          
          def pairs_regexp(l, r)
            /\A--(\d*)#{Regexp.escape(l)}([\d,]*)#{Regexp.escape(r)}\z/
          end
          
          def parse_pairs(lead, str, count=0)
             bracket = []
             str.split(/,+/).each do |n| 
               bracket << n.to_i unless n.empty?
             end

             [lead.empty? ? count : lead.to_i, bracket]
          end
        end
        
        ROUND = /\A--(\+(\d+)|\+*)\z/
        SEQUENCE = /\A--(\d*(:\d*)+)\z/
        FORK = pairs_regexp("[", "]")
        MERGE = pairs_regexp("{", "}")
        SYNC_MERGE = pairs_regexp("(", ")")
        INVALID =  /\A--(\z|[^A-Za-z])/
        
        def initialize(argv)
          @sequences = []
          @forks = []
          @merges = []
          @sync_merges = []
          
          current = []
          current_round = []
          @argvs = []
          @rounds = [current_round]
          
          argv.each do |arg|
            unless arg =~ INVALID
              current << arg
              next
            end
            
            # for peformance split to match
            # most arguments just once.
            unless current.empty?
              current_round << @argvs.length
              @argvs << current
              current = []
            end

            case arg
            when ROUND
              current_round = (@rounds[$2 ? $2.to_i : $1.length] ||= [])
            when SEQUENCE
              @sequences << CommandLine.parse_sequence($1, @argvs.length-1)
            when FORK
              @forks << CommandLine.parse_pairs($1, $2, @argvs.length-1)
            when MERGE
              @merges << CommandLine.parse_pairs($1, $2, @argvs.length-1)
            when SYNC_MERGE
              @sync_merges << CommandLine.parse_pairs($1, $2, @argvs.length-1)
            else 
              raise ArgumentError, "invalid argument: #{arg}"
            end
          end
          
          unless current.empty?
            current_round << @argvs.length
            @argvs << current
          end
          @rounds.delete_if {|round| round.nil? || round.empty? }
        end
        
      end
    end
  end
end
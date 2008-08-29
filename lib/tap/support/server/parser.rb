module Tap
  module Support
    module Server
      
      # rounds syntax
      # 0[task]=dump&0[config][key]=value&0[input][]=a&0[input][]=b
      # sequence[1]=1,2,3
      # fork[1]=2,3
      # round[0]=1,2,3
      # ....
      
      class Parser
        
        class << self
          def parse_argv(hash)
            raise ArgumentError, "no task specified" unless hash.has_key?('task')
            
            # parse task
            argv = [hash['task']]
            
            # parse configs
            configs = hash['config']
            configs = YAML.load(configs) if configs.kind_of?(String)
            
            case configs
            when Hash
              configs.each_pair do |key, value|
                argv << "--#{key}"
                argv << value
              end
            when nil
            else raise ArgumentError, "non-hash configs specified: #{configs}"
            end
            
            # parse inputs
            inputs = hash['inputs']
            inputs = YAML.load(inputs) if inputs.kind_of?(String)
            
            case inputs
            when Array then argv.concat(inputs)
            when nil
            else raise ArgumentError, "non-array inputs specified: #{inputs}"
            end
            
            argv
          end
          
          #--
          # Expects: 1,2,3
          def parse_sequence(values)
            [*values].collect do |value|
              value.split(',').collect {|i| i.to_i }
            end
          end
          
          def parse_pairs(values)
            parse_sequence(values).collect do |split|
              [split.shift, split]
            end
          end
        end
        
        attr_reader :argvs
        attr_reader :rounds
        attr_reader :sequences
        attr_reader :forks
        attr_reader :merges
        attr_reader :sync_merges
        
        INDEX = /\A\d+\z/
        SEQUENCE = "sequence"

        def initialize(argh)
          @argvs = []
          
          argh.each_pair do |key, value|
            case key
            when INDEX
              argvs[key.to_i] = Parser.parse_argv(value)
            when SEQUENCE
              @sequences = Parser.parse_sequence(value)
            else
              instance_variable_set("@#{key}s", Parser.parse_pairs(value))
            end 
          end
          
          @rounds ||= []
          @sequences ||= []
          @forks ||= []
          @merges ||= []
          @sync_merges ||= []
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
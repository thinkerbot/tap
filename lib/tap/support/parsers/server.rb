require 'tap/support/parsers/base'

module Tap
  module Support
    module Parsers
      
      # rounds syntax
      # 0[task]=dump&0[config][key]=value&0[input][]=a&0[input][]=b
      # sequence[1]=1,2,3
      # fork[1]=2,3
      # round[0]=1,2,3
      # ....
      
      class Server < Base
        
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
          
          def parse_pairs(values)
            [*values].collect do |value|
              value.split(',').collect {|i| i.to_i }
            end.collect do |split|
              [split.shift, split]
            end
          end
        end
        
        INDEX = /\A\d+\z/
        
        def initialize(argh)
          @argvs = []
          
          argh.each_pair do |key, value|
            case key
            when INDEX
              argvs[key.to_i] = Server.parse_argv(value)
            else
              instance_variable_set("@#{key}s", Server.parse_pairs(value))
            end 
          end
          
          @rounds ||= []
          @sequences ||= []
          @forks ||= []
          @merges ||= []
          @sync_merges ||= []
        end
      end
    end
  end
end
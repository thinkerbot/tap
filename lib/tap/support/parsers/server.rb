require 'tap/support/parsers/base'

module Tap
  module Support
    module Parsers
      
      # rounds syntax
      # 0[tasc]=dump&0[config][key]=value&0[input][]=a&0[input][]=b&0[selected]
      # sequence[1]=1,2,3
      # fork[1]=2,3
      # round[0]=1,2,3
      # ....
      
      class Server < Base
        
        class << self
          def parse_argv(hash)
            raise ArgumentError, "no task specified" unless hash.has_key?('tasc')

            # parse task
            argv = [hash.delete('tasc')]
            
            # parse configs
            configs = hash.delete('config')
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
            inputs = hash.delete('inputs')
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
              case value
              when String then value.split(',').collect {|i| i.to_i }
              when Array then value
              else raise ArgumentError, "non-array inputs specified: #{value}"
              end
            end.collect do |split|
              next if split.empty?
              [split.shift, split]
            end.compact
          end
          
          def compact(argh)
            compact = {}
            argh.each_pair do |key, value|
              compact[key] = case value
              when Array
                value.length == 1 && value[0].kind_of?(String) ? value[0] : value
              when Hash
                compact(value)
              else
                value
              end
            end
            compact
          end
        end
        
        INDEX = /\A\d+\z/
        
        attr_reader :attributes
        
        def initialize(argh)
          @argvs = []
          @attributes = []
          
          argh.each_pair do |key, value|
            case key
            when INDEX
              argvs[key.to_i] = Server.parse_argv(value)
              attributes[key.to_i] = value
            when "workflow"
              hash = value.kind_of?(String) ? YAML.load(value) : value
              unless hash.kind_of?(Hash)
                raise ArgumentError, "non-hash workflow specified: #{value}"
              end
                        
              hash.each_pair do |type, entries|
                instance_variable_set("@#{type}s", Server.parse_pairs(entries))
              end
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
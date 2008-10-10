module Tap
  module Support
    def self.Intern(method_name)
      mod = Module.new
      mod.module_eval %Q{
      attr_accessor :#{method_name}_block

      def #{method_name}(*inputs)
        raise "no #{method_name} block set" unless #{method_name}_block
        inputs.unshift(self)
      
        arity = #{method_name}_block.arity
        n = inputs.length
        unless n == arity || (arity < 0 && (-1-n) <= arity) 
          raise ArgumentError.new("wrong number of arguments (\#{n} for \#{arity})")
        end
      
        #{method_name}_block.call(*inputs)
      end
      
      def initialize_batch_obj(*args)
        super(*args).extend Tap::Support::Intern(:#{method_name})
      end
    }
      mod
    end
    
    Intern = Support.Intern(:process)
  end
end
module Tap
  module Support
    
    # Generates an Intern module for the specified method_name.
    # An Intern module:
    # - adds an accessor for <method_name>_block
    # - overrides <method_name> to call the block
    # - ensures initialize_batch_obj extends the batch object
    #   with the same Intern module
    #
    def self.Intern(method_name)
      mod = INTERN_MODULES[method_name.to_sym]
      return mod unless mod == nil
      
      mod = INTERN_MODULES[method_name.to_sym] = Module.new
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
    
    # An array of already-declared intern modules,
    # keyed by method_name.
    INTERN_MODULES = {}
    
    # An Intern module for :process.
    Intern = Support.Intern(:process)
  end
end
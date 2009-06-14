module Tap
  # Generates an Intern module to override the specified method_name.  Intern
  # modules are useful to override a tiny bit of functionality without having
  # to generate a full subclass.
  #
  # An Intern module:
  #
  # - adds an accessor for <method_name>_block
  # - overrides <method_name> to call the block, prepending self to
  #   the input arguments
  #
  # For example:
  #
  #   array = [1,2,3].extend Intern(:last)
  #
  #   array.last             # => 3
  #   array.last_block = lambda {|arr| arr.first }
  #   array.last             # => 3
  #
  def self.Intern(method_name)
    mod = INTERN_MODULES[method_name.to_sym]
    return mod unless mod == nil

    mod = INTERN_MODULES[method_name.to_sym] = Module.new
    mod.module_eval %Q{
    attr_accessor :#{method_name}_block

    def #{method_name}(*inputs)
      return super unless #{method_name}_block
      inputs.unshift(self)

      arity = #{method_name}_block.arity
      n = inputs.length
      unless n == arity || (arity < 0 && (-1-n) <= arity) 
        raise ArgumentError.new("wrong number of arguments (\#{n} for \#{arity})")
      end

      #{method_name}_block.call(*inputs)
    end
    }
    mod
  end
  
  # An array of already-declared intern modules,
  # keyed by method_name.
  INTERN_MODULES = {}
  
  # An Intern module for :process.
  Intern = Tap::Intern(:process)
end
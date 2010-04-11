require 'tap/signals/class_methods'

module Tap
  module Signals
    module ModuleMethods
      module_function
    
      # Extends including classes with Configurable::ClassMethods
      def included(base)
        super
        base.extend ClassMethods
        base.extend ModuleMethods unless base.kind_of?(Class)

        # initialize any class variables
        ClassMethods.initialize(base)
      end
    end
  
    extend ModuleMethods
  end
end
module Tap
  module Generator
    
    # A special type of Lazydoc::Arguments that shifts off the standard 'm'
    # argument on generator manifest methods, to properly reflect how may
    # arguments the generator should receive.
    class Arguments < Lazydoc::Arguments
      def arguments(shift_manifest_arg=true)
        shift_manifest_arg ? @arguments[1..-1] : @arguments
      end
    end
  end
end

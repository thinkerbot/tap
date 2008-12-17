module Tap
  module Generator
    class Arguments < Lazydoc::Arguments
      def arguments(shift_manifest_arg=true)
        shift_manifest_arg ? @arguments[1..-1] : @arguments
      end
    end
  end
end

module Tap
  module Support
    module Lazydoc
      class Config < Comment
        def empty?
          to_str.empty?
        end

        def to_str
          # currently removes the :no_default: document modifier
          # which is used during generation of TDoc
          subject.to_s =~ /#\s*(:no_default:)?\s*(.*)$/ ? $2.strip : ""
        end
      end
    end
  end
end
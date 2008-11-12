require 'tap/support/lazydoc'

module Tap
  module Support
    module Lazydoc
      # Attributes adds methods to declare class-level accessors
      # for Lazydoc attributes.  The source_file for the class must
      # be set manually.
      #
      #   # ConstName::key value
      #   class ConstName
      #     class << self
      #       include Lazydoc::Attributes
      #     end
      #
      #     self.source_file = __FILE__
      #     lazy_attr :key
      #   end
      #
      #   ConstName::key.subject           # => 'value'
      # 
      module Attributes
      
        # The source_file for self.  Must be set independently.
        attr_accessor :source_file
      
        # Returns the lazydoc for source_file
        def lazydoc(resolve=true)
          lazydoc = Lazydoc[source_file]
          lazydoc.resolve if resolve
          lazydoc
        end
      
        # Creates a lazy attribute accessor for the specified attribute.
        def lazy_attr(key, attribute=key)
          instance_eval %Q{
          def #{key}
            lazydoc[to_s]['#{attribute}'] ||= Lazydoc::Comment.new
          end

          def #{key}=(comment)
            Lazydoc[source_file][to_s]['#{attribute}'] = comment
          end}
        end
      end 
    end
  end
end
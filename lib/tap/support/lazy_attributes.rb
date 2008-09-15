require 'tap/support/lazydoc'

module Tap
  module Support
    module LazyAttributes
      
      # The source_file for self.  Must be set independently.
      attr_accessor :source_file
      
      # Returns the lazydoc for source_file
      def lazydoc(resolve=true)
        lazydoc = Lazydoc[source_file]
        lazydoc.resolve if resolve
        lazydoc
      end
      
      # Creates a lazy attribute reader for the specified attribute.
      def lazy_attr(key, attribute=key)
        instance_eval %Q{def #{key}; @#{key} ||= get_lazy_attr('#{attribute}'); end}
      end
      
      private
      
      def get_lazy_attr(attribute)
        lazydoc[self.to_s][attribute] ||= Lazydoc::Comment.new
      end
      
    end 
  end
end
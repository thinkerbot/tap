module Tap
  module Support
    class Constant
      attr_reader :name, :path
  
      def initialize(name, path)
        @name = name.camelize
        @path = path
      end
  
      def document
        Support::Lazydoc[path]  
      end
  
      def constantize
        name.try_constantize do |const_name|
          require path
          name.constantize
        end
      end
    end
  end
end
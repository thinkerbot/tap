module Tap
  module Declarations
    class Declaration < Lazydoc::Comment
      attr_accessor :desc
      
      def prepend(line)
        if line =~ /::desc\s+(.*?)\s*$/
          self.desc = $1
          false
        else
          super
        end
      end
      
      def to_s
        resolve
        desc.to_s
      end
    end
  end
end
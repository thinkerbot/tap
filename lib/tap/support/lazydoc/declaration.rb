module Tap
  module Support
    module Lazydoc
      class Declaration < Comment
        def resolve(lines)
          super
            
          @subject = case
          when content.empty? || content[0][0].to_s !~ /^::desc(.*)/ then ""
          else
            content[0].shift
            $1.strip
          end
            
          self
        end
      end
    end
  end
end
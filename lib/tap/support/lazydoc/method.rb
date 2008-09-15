module Tap
  module Support
    module Lazydoc
      class Method < Comment
        def resolve(lines)
          super
          @subject =~ /def \w+(\((.*?)\))?/

          args = $2.to_s.split(',').collect do |arg|
            arg = arg.strip.upcase
            case arg
            when /^&/ then nil
            when /^\*/ then arg[1..-1] + "..."
            else arg
            end
          end

          @subject = args.join(', ')
          self
        end
      end
    end
  end
end
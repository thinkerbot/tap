module Tap
  module Support
    module Lazydoc
      class Definition < Comment
        attr_accessor :subclass
        
        def configurations(fragment_sep=" ", line_sep="\n", strip=true)
          lines = []
          subclass.configurations.each do |receiver, key, config|
            desc = config.desc
            case desc
            when Definition
              lines << "# #{desc.subclass}"
              lines.concat desc.original_to_s(fragment_sep, nil, strip).collect {|line| "# #{line}"}
              lines << "#{key}:"
              lines.concat desc.configurations(fragment_sep).collect {|line| "  #{line}"}
            else 
              lines << "# #{desc}"
              lines << "#{key}: #{config.default}"
              lines << ""
            end
          end
          
          lines
        end
        
        alias original_to_s to_s
        
        def to_s(fragment_sep=" ", line_sep="\n", strip=true)
          lines = [original_to_s(fragment_sep, line_sep, strip)] + configurations(fragment_sep)
          line_sep ? lines.join(line_sep) : lines
        end
      end
    end
  end
end
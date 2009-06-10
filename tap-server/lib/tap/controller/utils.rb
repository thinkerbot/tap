module Tap
  class Controller
    module Utils
      
      def static_file(path)
        content = File.read(path)
        headers = {
          "Last-Modified" => File.mtime(path).httpdate,
          "Content-Type" => Rack::Mime.mime_type(File.extname(path), 'text/plain'), 
          "Content-Length" => content.size.to_s
        }
    
        [200, headers, [content]]
      end
      
      def download(path)
        content = File.read(path)
        headers = {
          "Last-Modified" => File.mtime(path).httpdate,
          "Content-Type" => Rack::Mime.mime_type(File.extname(path), 'text/plain'), 
          "Content-Disposition" => "attachment; filename=#{File.basename(path)};",
          "Content-Length" => content.size.to_s
        }
    
        [200, headers, [content]]
      end
      
      def yamlize(obj, indent="")
        case obj
        when Hash
          lines = []
          obj.each_pair do |key, value|
            lines << case value
            when Hash, Array
              "#{indent}#{key}:\n#{yamlize(value, indent + '  ')}"
            else
              "#{indent}#{key}: #{value}"
            end
          end
          lines.join("\n")
        when Array
          lines = obj.collect do |value|
            case value
            when Hash, Array
              "#{indent}-\n#{yamlize(value, indent + '  ')}"
            else
              "#{indent}- #{value}"
            end
          end
          lines.join("\n")
        else
          obj
        end
      end
      
    end
  end
end
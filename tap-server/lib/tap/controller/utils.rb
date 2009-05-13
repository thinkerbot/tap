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
    end
  end
end
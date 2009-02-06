module Tap
  module Models
    class Tail
      attr_reader :path
      attr_reader :pos

      def initialize(path)
        @path = path
        @pos = 0
      end

      def content
        if pos > File.size(path)
          raise ServerError.new("position out of range", 500)
        end

        File.open(path) do |file|
          file.pos = pos
          content = file.read
          @pos = file.pos
          content
        end
      end
    end
  end
end
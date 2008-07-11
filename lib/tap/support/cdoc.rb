require 'tap/support/document'

module Tap
  module Support
    class CDoc
      
      class << self
        attr_writer :instance
        
        def instance
          @instance ||= CDoc.new
        end  
      end
      
      # A hash of (source_file, [CodeComment]) pairs that
      # tracks which lines are registered for documentation
      # for the given source file.  Source file keys are
      # keyified using CDoc#key.
      attr_reader :registry

      def initialize
        @registry = {}
      end
      
      def document_for(source_file)
        source_file = File.expand_path(source_file)
        registry[source_file] ||= Document.new(source_file)
      end

      # CDoc the specified line numbers to source_file.
      # Returns a CodeComment object corresponding to the line.
      def register(source_file, line_number=nil)
        document = document_for(source_file)
        document.register(line_number) if line_number != nil
        document
      end

      # Returns true if the comments for source_file are frozen.
      def resolved?(source_file)
        document_for(source_file).resolved?
      end

      def resolve(source_file, str=nil)
        document_for(source_file).resolve(str)
      end
    end
  end
end
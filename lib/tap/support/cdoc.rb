require 'tap/support/document'

module Tap
  module Support
    class CDoc
      
      class << self
        attr_writer :instance
        
        def instance
          @instance ||= CDoc.new
        end
        
        def usage(str, cols=80)
          scanner = StringScanner.new(str)
          scanner.scan(/^#!.*?$/)
          Comment.parse(scanner, false).to_s(" ", "\n", cols, 2)
        end
        
      end
      
      # A hash of (source_file, [CodeComment]) pairs that
      # tracks which lines are registered for documentation
      # for the given source file.  Source file keys are
      # keyified using CDoc#key.
      attr_reader :registry

      def initialize
        @registry = []
      end
      
      # Returns the document in registry for the specified source file.
      # If no such document exists, one will be created for it.
      def document_for(source_file)
        source_file = File.expand_path(source_file)
        document = registry.find {|doc| doc.source_file == source_file }
        if document == nil
          document = Document.new(source_file)
          registry << document
        end
        document
      end
      
      # Returns an array of documents in registry for which
      # document.has_const?(const_name) == true
      def documents_for_const(const_name)
        registry.select do |document| 
          document.has_const?(const_name)
        end
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
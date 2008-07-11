require 'tap/support/comment'

module Tap
  module Support

    class Document
      
      # $1:: namespace
      # $3:: key
      # $4:: flag char
      ATTRIBUTE_REGEXP = /(::|([A-Z][A-z]*::)+)([a-z_]+)(-?)/
      CONSTANT_REGEXP = /(::|([A-Z][A-z]*::)+)/
      
      class << self
        def scan(str, key) # :yields: namespace, key, value
          scanner = case str
          when StringScanner then str
          when String then StringScanner.new(str)
          else raise ArgumentError, "expected StringScanner or String"
          end
   
          regexp = /(#{key})([ \t-].*$|$)/
          while !scanner.eos?
            break if scanner.skip_until(CONSTANT_REGEXP) == nil
            namespace = scanner[1]
            
            case
            when scanner.scan(regexp)
              yield(namespace.chomp('::'), scanner[1], scanner[2].strip)
            when scanner.scan(/:-/)
              scanner.skip_until(/:\+/)
            end
          end
        
          scanner
        end
      
        def parse(str) # :yields: namespace, key, comment
          scanner = case str
          when StringScanner then str
          when String then StringScanner.new(str)
          else raise ArgumentError, "expected StringScanner or String"
          end
          
          scan(scanner, '[a-z_]+') do |namespace, key, value|
            comment = Comment.parse(scanner, false) do |comment|
              if comment =~ /::/ && comment =~ ATTRIBUTE_REGEXP
                # rewind to capture the next attribute unless an end is specified.
                scanner.unscan unless !$4.empty? && $1.chomp("::") == namespace && $3 == key
                true
              else false
              end
            end
            comment.subject = value
            yield(namespace, key, comment)
          end
        end
      end
      
      attr_accessor :source_file
      attr_reader :code_comments
      attr_reader :attributes

      def initialize(source_file=nil, code_comments=[], attributes={})
        @source_file = source_file
        @code_comments = code_comments
        @attributes = attributes
        @resolved = false
      end

      # CDoc the specified line numbers to source_file.
      # Returns a Comment object corresponding to the line.
      def register(line_number)
        comment = code_comments.find {|c| c.line_number == line_number }

        if comment == nil
          comment = Comment.new(line_number)
          code_comments << comment
        end

        comment
      end

      # Returns true if the code_comments for source_file are frozen.
      def resolved?
        @resolved
      end

      def resolve(str=nil)
        return(false) if resolved?
        
        if str == nil 
          raise ArgumentError, "no source file specified" unless source_file && File.exists?(source_file)
          str = File.read(source_file)
        end
        
        Document.parse(str) do |namespace, key, comment|
          (attributes[namespace] ||= {})[key] = comment
        end
        
        lines = str.split(/\r?\n/)

        code_comments.collect! do |comment|
          line_number = comment.line_number
          comment.subject = lines[line_number]

          # remove whitespace lines
          line_number -= 1
          while lines[line_number].strip.empty?
            line_number -= 1
          end

          # put together the comment
          while line_number >= 0
            break unless comment.prepend(lines[line_number])
            line_number -= 1
          end

          comment
        end
        
        @resolved = true
      end
    end
  end
end
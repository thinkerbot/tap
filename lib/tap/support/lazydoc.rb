require 'tap/support/comment'

module Tap
  module Support
    
    #-- 
    # attributes scan down:
    #
    #   # ::key subject
    #   # comment
    #   # line
    #
    # code comments scan up:
    #
    #   # comment
    #   # lines
    #   code_comment_line # subject
    #
    class Lazydoc
      
      # $1:: const_name
      # $3:: key
      # $4:: flag char
      ATTRIBUTE_REGEXP = /(::|([A-Z][A-z]*::)+)([a-z_]+)(-?)/
      CONSTANT_REGEXP = /(::|([A-Z][A-z]*::)+)/
      
      class << self
        
        def scan_doc(path, key)
          document = self[path]
          scan(File.read(path), key) do |const_name, key, comment|
            document.attributes(const_name)[key] = comment
          end
          document
        end
        
        def scan(str, key) # :yields: const_name, key, value
          scanner = case str
          when StringScanner then str
          when String then StringScanner.new(str)
          else raise TypeError, "can't convert #{str.class} into StringScanner or String"
          end
   
          regexp = /(#{key})([ \r\t-].*$|$)/
          while !scanner.eos?
            break if scanner.skip_until(CONSTANT_REGEXP) == nil
            const_name = scanner[1]
            
            case
            when scanner.scan(regexp)
              yield(const_name.chomp('::'), scanner[1], scanner[2].strip)
            when scanner.scan(/:-/)
              scanner.skip_until(/:\+/)
            end
          end
        
          scanner
        end
      
        def parse(str) # :yields: const_name, key, comment
          scanner = case str
          when StringScanner then str
          when String then StringScanner.new(str)
          else raise TypeError, "can't convert #{str.class} into StringScanner or String"
          end
          
          scan(scanner, '[a-z_]+') do |const_name, key, value|
            comment = Comment.parse(scanner, false) do |line|
              if line =~ /::/ && line =~ ATTRIBUTE_REGEXP
                # rewind to capture the next attribute unless an end is specified.
                scanner.unscan unless !$4.empty? && $1.chomp("::") == const_name && $3 == key
                true
              else false
              end
            end
            comment.subject = value
            yield(const_name, key, comment)
          end
        end

        # A hash of (source_file, [CodeComment]) pairs that
        # tracks which lines are registered for documentation
        # for the given source file.  Source file keys are
        # keyified using Lazydoc#key.
        def registry
          @registry ||= []
        end
        
        # Returns the document in registry for the specified source file.
        # If no such document exists, one will be created for it.
        def [](source_file)
          source_file = File.expand_path(source_file.to_s)
          document = registry.find {|doc| doc.source_file == source_file }
          if document == nil
            document = new(source_file)
            registry << document
          end
          document
        end

        # Lazydoc the specified line numbers to source_file.
        # Returns a CodeComment object corresponding to the line.
        def register(source_file, line_number)
          Lazydoc[source_file].register(line_number)
        end

        def resolve(code_comments)
          registry.each do |doc|
            next if (code_comments & doc.code_comments).empty?
            doc.resolve
          end
        end
      end
      
      include Enumerable
      
      # The source file for self, used in resolving comments and
      # attributes.
      attr_reader :source_file
      
      # An array of Comment objects identifying lines resolved or
      # to-be-resolved for self.
      attr_reader :code_comments
      
      # A hash of (const_name, attributes) pairs tracking the constant 
      # attributes resolved or to-be-resolved for self.
      attr_reader :const_attrs

      def initialize(source_file=nil)
        self.source_file = source_file
        @code_comments = []
        @const_attrs = {}
        @resolved = false
      end
      
      # Sets the source file for self.  Expands the source file path if necessary.
      def source_file=(source_file)
        @source_file = source_file == nil ? nil : File.expand_path(source_file)
      end

      # Returns the attributes for the specified const_name.
      def attributes(const_name)
        const_attrs[const_name] ||= {}
      end
      
      # Returns default document attributes (ie attributes(''))
      def default_attributes
        attributes('')
      end
      
      # Returns the attributes for const_name merged to the default
      # document attributes.
      def [](const_name)
        default_attributes.merge(attributes(const_name))
      end
      
      # Yields each const_name and attributes to the block; const_names where
      # the attributes are empty are skipped.
      def each
        const_attrs.each_pair do |const_name, attrs|
          yield(const_name, attrs) unless attrs.empty?
        end
      end
      
      def has_const?(const_name)
        const_attrs.each_pair do |constname, attrs|
          next unless constname == const_name
          return !attrs.empty?
        end
        
        false
      end
      
      def const_names
        names = []
        const_attrs.each_pair do |const_name, attrs|
          names << const_name unless attrs.empty?
        end
        names
      end

      # Lazydoc the specified line numbers to source_file.
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
      
      attr_writer :resolved
      
      def resolve(str=nil, comment_regexp=nil) # :yields: comment, match
        return(false) if resolved?
        
        if str == nil 
          raise ArgumentError, "no source file specified" unless source_file && File.exists?(source_file)
          str = File.read(source_file)
        end
        
        Lazydoc.parse(str) do |const_name, key, comment|
          attributes(const_name)[key] = comment
        end
        
        lines = str.split(/\r?\n/)
        lines.each_with_index do |line, line_number|
          next unless line =~ comment_regexp
          comment = register(line_number)
          yield(comment, $~) if block_given?
        end unless comment_regexp == nil
          
        code_comments.collect! do |comment|
          line_number = comment.line_number
          comment.subject = lines[line_number] if comment.subject == nil

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
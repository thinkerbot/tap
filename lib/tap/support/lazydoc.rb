require 'tap/support/comment'

module Tap
  module Support
    
    # Lazydoc scans source files to pull out documentation.  Lazydoc can find two
    # types of documentation, constant attributes and code comments.
    #
    # === Constant Attributes
    #
    # Constant attributes are designated the same as constants in Ruby, but with
    # an extra 'key' constant that must consist of only lowercase letters and/or
    # underscores.  Attributes are only parsed from comment lines.
    #
    # When Lazydoc finds an attribute it parses a Comment value where the subject
    # is the remainder of the line, and comment lines are parsed down until a
    # non-comment line, an end key, or a new attribute is reached.
    #
    #   str = %Q{
    #   # Const::Name::key subject for key
    #   # comment for key
    #   # parsed until a non-comment line
    #
    #   # Const::Name::another subject for another
    #   # comment for another
    #   # parsed to an end key
    #   # Const::Name::another-
    #   #
    #   # ignored comment
    #   }
    #
    #   lazydoc = Lazydoc.new
    #   lazydoc.resolve(str)
    #
    #   lazydoc.to_hash {|comment| [comment.subject, comment.to_s] } 
    #   # => {'Const::Name' => {
    #   #  'key' =>     ['subject for key', 'comment for key parsed until a non-comment line'],
    #   #  'another' => ['subject for another', 'comment for another parsed to an end key']
    #   # }}
    #
    # A constant name does not need to be specified; when no constant name is
    # specified, Lazydoc will store the key as a default for the document. To
    # turn off attribute parsing for a section of documentation, use start/stop
    # keys:
    #
    #   str = %Q{
    #   # :::-
    #   # Const::Name::not_parsed
    #   # :::+
    #
    #   Const::Name::not_parsed
    #
    #   # Const::Name::parsed subject
    #   }
    #
    #   lazydoc = Lazydoc.new
    #   lazydoc.resolve(str)
    #   lazydoc.to_hash {|comment| comment.subject }   # => {'Const::Name' => {'parsed' => 'subject'}}
    #
    # ==== startdoc
    #
    # Lazydoc is completely separate from RDoc, but the syntax of Lazydoc was developed
    # with RDoc in mind.  To hide attributes in one line, make use of the RDoc 
    # <tt>:startdoc:</tt> document modifier like this (spaces added to keep them in the
    # example):
    #
    #   # :start doc::Const::Name::one hidden in RDoc
    #   # * This line is visible in RDoc.
    #   # :start doc::Const::Name::one-
    #   # 
    #   #-- 
    #   # Const::Name::two
    #   # You can hide attribute comments like this.
    #   # Const::Name::two-
    #   #++
    #   #
    #   # * This line is also visible in RDoc.
    #
    # Here is the same text, actually in RDoc:
    #
    # :startdoc::Const::Name::one hidden in RDoc
    # * This line is visible in RDoc.
    # :startdoc::Const::Name::one-
    # 
    #-- 
    # Const::Name::two
    # You can hide attribute comments like this.
    # Const::Name::two-
    #++
    #
    # * This line is also visible in RDoc.
    #
    # === Code Comments
    #
    # Code comments are lines marked for parsing if and when a Lazydoc gets resolved.
    # Unlike constant attributes, the line is the subject of a code comment and
    # comment lines are parsed up from it (effectively mimicking the behavior of
    # RDoc).
    #
    #   str = %Q{
    #   # comment lines for
    #   # the method
    #   def method
    #   end
    #
    #   # as in RDoc, the comment can be
    #   # separated from the method
    #
    #   def another_method
    #   end
    #   }
    #
    #   lazydoc = Lazydoc.new
    #   lazydoc.register(3)
    #   lazydoc.register(9)
    #   lazydoc.resolve(str)
    #
    #   lazydoc.code_comments.collect {|comment| [comment.subject, comment.to_s] } 
    #   # => [
    #   # ['def method', 'comment lines for the method'],
    #   # ['def another_method', 'as in RDoc, the comment can be separated from the method']]
    #
    class Lazydoc
      
      # A regexp matching an attribute start or end.  For the match:
      #
      # $1:: const_name
      # $3:: key
      # $4:: end flag
      #
      ATTRIBUTE_REGEXP = /(.*)::([a-z_]+)(-?)/
      
      # A regexp matching constants from the ATTRIBUTE_REGEXP leader
      CONSTANT_REGEXP = /([A-Z][A-z]*(::[A-Z][A-z]*)*)$/
      
      class << self
        
        # A hash of (source_file, lazydoc) pairs tracking the
        # Lazydoc instance for the given source file.
        def registry
          @registry ||= []
        end
        
        # Returns the lazydoc in registry for the specified source file.
        # If no such lazydoc exists, one will be created for it.
        def [](source_file)
          source_file = File.expand_path(source_file.to_s)
          lazydoc = registry.find {|doc| doc.source_file == source_file }
          if lazydoc == nil
            lazydoc = new(source_file)
            registry << lazydoc
          end
          lazydoc
        end

        # Register the specified line numbers to the lazydoc for source_file.
        # Returns a CodeComment corresponding to the line.
        def register(source_file, line_number)
          Lazydoc[source_file].register(line_number)
        end
        
        # Resolves all lazydocs which include the specified code comments.
        def resolve(code_comments)
          registry.each do |doc|
            next if (code_comments & doc.code_comments).empty?
            doc.resolve
          end
        end
        
        # Scans the specified file for attributes keyed by key and stores 
        # the resulting comments in the corresponding lazydoc.
        # Returns the lazydoc.
        def scan_doc(source_file, key)
          lazydoc = nil
          scan(File.read(source_file), key) do |const_name, attr_key, comment|
            lazydoc = self[source_file] unless lazydoc
            lazydoc.attributes(const_name)[attr_key] = comment
          end
          lazydoc
        end
        
        # Scans the string or StringScanner for attributes matching the key;
        # keys may be patterns, they are incorporated into a regexp. Yields 
        # each (const_name, key, value) triplet to the mandatory block and
        # skips regions delimited by the stop and start keys <tt>:-</tt> 
        # and <tt>:+</tt>.
        #
        #   str = %Q{
        #   # Const::Name::key value
        #   # ::alt alt_value
        #
        #   # Ignored::Attribute::not_matched value
        #   # :::-
        #   # Also::Ignored::key value
        #   # :::+
        #   # Another::key another value
        #   }
        #
        #   results = []
        #   Lazydoc.scan(str, 'key|alt') do |const_name, key, value|
        #     results << [const_name, key, value]
        #   end
        #
        #   results    
        #   # => [
        #   # ['Const::Name', 'key', 'value'], 
        #   # ['', 'alt', 'alt_value'], 
        #   # ['Another', 'key', 'another value']]
        #
        # Returns the StringScanner used during scanning.
        def scan(str, key) # :yields: const_name, key, value
          scanner = case str
          when StringScanner then str
          when String then StringScanner.new(str)
          else raise TypeError, "can't convert #{str.class} into StringScanner or String"
          end

          regexp = /^(.*?)\s+::(:-|#{key})/
          while !scanner.eos?
            break if scanner.skip_until(regexp) == nil

            if scanner[2] == ":-"
              scanner.skip_until(/:::\+/)
            else
              key = scanner[2]
              const_name = scanner[1] =~ CONSTANT_REGEXP ? $1 : ""
              yield(const_name, key, scanner.matched.strip) if scanner.scan(/[ \r\t-](.*)$|$/)
            end
          end
        
          scanner
        end
      
        # Parses constant attributes from the string or StringScanner.  Yields 
        # each (const_name, key, comment) triplet to the mandatory block 
        # and skips regions delimited by the stop and start keys <tt>:-</tt> 
        # and <tt>:+</tt>.
        #
        #   str = %Q{
        #   # Const::Name::key subject for key
        #   # comment for key
        #
        #   # :::-
        #   # Ignored::key value
        #   # :::+
        #
        #   # Ignored text before attribute ::another subject for another
        #   # comment for another
        #   }
        #
        #   results = []
        #   Lazydoc.parse(str) do |const_name, key, comment|
        #     results << [const_name, key, comment.subject, comment.to_s]
        #   end
        #
        #   results    
        #   # => [
        #   # ['Const::Name', 'key', 'subject for key', 'comment for key'], 
        #   # ['', 'another', 'subject for another', 'comment for another']]
        #
        # Returns the StringScanner used during scanning.
        def parse(str) # :yields: const_name, key, comment
          scanner = case str
          when StringScanner then str
          when String then StringScanner.new(str)
          else raise TypeError, "can't convert #{str.class} into StringScanner or String"
          end
          
          scan(scanner, '[a-z_]+') do |const_name, key, value|
            comment = Comment.parse(scanner, false) do |line|
              if line =~ ATTRIBUTE_REGEXP
                # rewind to capture the next attribute unless an end is specified.
                scanner.unscan unless !$3.empty? && $2 == key && $1.strip =~ /#{const_name}$/ 
                true
              else false
              end
            end
            comment.subject = value
            yield(const_name, key, comment)
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
      # attributes resolved or to-be-resolved for self.  Attributes
      # are hashes of (key, comment) pairs.
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
      
      # Returns the attributes for const_name merged to default_attributes.  
      # Set merge_defaults to false to get just the attributes for const_name.
      def [](const_name, merge_defaults=true)
        merge_defaults ? default_attributes.merge(attributes(const_name)) : attributes(const_name)
      end
      
      # Yields each (const_name, attributes) pair to the block; const_names where
      # the attributes are empty are skipped.
      def each
        const_attrs.each_pair do |const_name, attrs|
          yield(const_name, attrs) unless attrs.empty?
        end
      end
      
      # Returns true if the attributes for const_name are not empty.
      def has_const?(const_name)
        const_attrs.each_pair do |constname, attrs|
          next unless constname == const_name
          return !attrs.empty?
        end
        
        false
      end
      
      # Returns an array of the constant names in self, for which
      # the constant attributes are not empty.
      def const_names
        names = []
        const_attrs.each_pair do |const_name, attrs|
          names << const_name unless attrs.empty?
        end
        names
      end

      # Register the specified line number to self.  Returns a 
      # Comment object corresponding to the line.
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
      
      def to_hash
        const_hash = {}
        const_names.sort.each do |const_name|
          attr_hash = {}
          self[const_name, false].each_pair do |key, comment|
            attr_hash[key] = (block_given? ? yield(comment) : comment)
          end
          const_hash[const_name] = attr_hash
        end
        const_hash
      end
    end
  end
end
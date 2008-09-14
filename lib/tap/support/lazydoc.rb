require 'tap/support/comment'

module Tap
  module Support
    
    # Lazydoc scans source files to pull out documentation.  Lazydoc can find two
    # types of documentation, constant attributes and code comments, and works
    # with LazyAttributes to make documentation available in the code.  First,
    # an example:
    #
    #   # Sample::key <this is the subject line>
    #   # a constant attribute content string that
    #   # can span multiple lines...
    #   #
    #   #   code.is_allowed
    #   #   much.as_in RDoc
    #   #
    #   # and stops at the next non-comment
    #   # line, the next constant attribute,
    #   # or an end key
    #   class Sample
    #     extend Tap::Support::LazyAttributes
    #     self.source_file = __FILE__
    #
    #     lazy_attr :key
    #
    #     # comment content for a code comment
    #     # may similarly span multiple lines
    #     def method_one
    #     end
    #   end
    #   
    # Although the comments are normally not available in the code, lazy_attrs 
    # reach into the source file to allow the following:
    #
    #   comment = Sample::key
    #   comment.subject       # => "<this is the subject line>"
    #   comment.content       
    #   # => [
    #   # ["a constant attribute content string that", "can span multiple lines..."],
    #   # [""],
    #   # ["  code.is_allowed"],
    #   # ["  much.as_in RDoc"],
    #   # [""],
    #   # ["and stops at the next non-comment", "line, the next constant attribute,", "or an end key"]]
    #
    #   "\n#{'.' * 30}\n" + comment.wrap(30) + "\n#{'.' * 30}\n"
    #   # => %q{
    #   # ..............................
    #   # a constant attribute content
    #   # string that can span multiple
    #   # lines...
    #   # 
    #   #   code.is_allowed
    #   #   much.as_in RDoc
    #   # 
    #   # and stops at the next
    #   # non-comment line, the next
    #   # constant attribute, or an end
    #   # key
    #   # ..............................
    #   #}
    #
    # Individual lines of code may be singled out and resolved by Lazydoc.
    # Here, a Regexp is used to identify the line that gets turned into a 
    # Comment (note that in this case the Lazydoc needs to be reset to 
    # resolve the new comment):
    #
    #   lazydoc = Sample.lazydoc.reset
    #   comment = lazydoc.register(/method_one/)
    #   
    #   lazydoc.resolve
    #   comment.subject       # => "  def method_one"
    #   comment.content       # => [["comment content for a code comment", "may similarly span multiple lines"]]
    #
    # And with the basics in mind, here are some details...
    #
    # === Constant Attributes
    # Constant attributes are designated the same as constants in Ruby, but with
    # an extra 'key' constant that must consist of only lowercase letters and/or
    # underscores.  For example, these are constant attributes:
    #
    #   # Const::Name::key
    #   # Const::Name::key_with_underscores
    #   # ::key
    #
    # While these are not:
    #
    #   # Const::Name::Key
    #   # Const::Name::key2
    #   # Const::Name::k@y
    #
    # Lazydoc parses a Comment for each constant attribute by using the remainder 
    # of the line as a subject and scanning down for comment content until a
    # non-comment line, an end key, or a new attribute is reached; the comment 
    # is then stored by constant name and key.
    #
    #   str = %Q{
    #   # Const::Name::key subject for key
    #   # comment for key
    #   # parsed until a 
    #   # non-comment line
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
    # Attributes are only parsed from commented lines.  To turn off attribute
    # parsing for a section of documentation, use start/stop keys:
    #
    #   str = %Q{
    #   Const::Name::not_parsed
    #
    #   # :::-
    #   # Const::Name::not_parsed
    #   # :::+
    #   # Const::Name::parsed subject
    #   }
    #
    #   lazydoc = Lazydoc.new
    #   lazydoc.resolve(str)
    #   lazydoc.to_hash {|comment| comment.subject }   # => {'Const::Name' => {'parsed' => 'subject'}}
    #
    # To hide attributes from RDoc, make use of the RDoc <tt>:startdoc:</tt> 
    # document modifier like this (spaces added to keep them in the example):
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
    # Here is the same text, for comparison if you are reading this as RDoc:
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
    # Code comments are lines registered for parsing if and when a Lazydoc gets 
    # resolved. Unlike constant attributes, the registered line is the comment
    # subject and the comment content is parsed up from it (basically mimicking 
    # the behavior of RDoc).
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
    #   lazydoc.comments.collect {|comment| [comment.subject, comment.to_s] } 
    #   # => [
    #   # ['def method', 'comment lines for the method'],
    #   # ['def another_method', 'as in RDoc, the comment can be separated from the method']]
    #
    # Comments may be registered to specific line numbers, or with a Proc or
    # Regexp that will determine the line number during resolution.  In the case
    # of a Regexp, the first matching line is used; Procs receive the lines of 
    # the document and return the line that should be used.  See Comment#resolve
    # for more details.
    #
    class Lazydoc
      
      # A regexp matching an attribute start or end.  After a match:
      #
      # $1:: const_name
      # $3:: key
      # $4:: end flag
      #
      ATTRIBUTE_REGEXP = /([A-Z][A-z]*(::[A-Z][A-z]*)*)?::([a-z_]+)(-?)/
    
      # A regexp matching constants from the ATTRIBUTE_REGEXP leader
      CONSTANT_REGEXP = /#.*?([A-Z][A-z]*(::[A-Z][A-z]*)*)?$/
      
      # A regexp matching a caller line, to extract the calling file
      # and line number.  After a match:
      #
      # $1:: file
      # $3:: line number (as a string, obviously)
      #
      # Note that line numbers in caller start at 1, not 0.
      CALLER_REGEXP = /^(([A-z]:)?[^:]+):(\d+)/
      
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
        # Returns a comment_class instance corresponding to the line.
        def register(source_file, line_number, comment_class=Comment)
          Lazydoc[source_file].register(line_number, comment_class)
        end
        
        # Resolves all lazydocs which include the specified code comments.
        def resolve_comments(comments)
          registry.each do |doc|
            next if (comments & doc.comments).empty?
            doc.resolve
          end
        end
        
        # Scans the specified file for attributes keyed by key and stores 
        # the resulting comments in the source_file lazydoc. Returns the
        # lazydoc.
        def scan_doc(source_file, key)
          lazydoc = nil
          scan(File.read(source_file), key) do |const_name, attr_key, comment|
            lazydoc = self[source_file] unless lazydoc
            lazydoc[const_name][attr_key] = comment
          end
          lazydoc
        end
        
        # Scans the string or StringScanner for attributes matching the key
        # (keys may be patterns, they are incorporated into a regexp). Yields 
        # each (const_name, key, value) triplet to the mandatory block and
        # skips regions delimited by the stop and start keys <tt>:-</tt> 
        # and <tt>:+</tt>.
        #
        #   str = %Q{
        #   # Const::Name::key value
        #   # ::alt alt_value
        #   #
        #   # Ignored::Attribute::not_matched value
        #   # :::-
        #   # Also::Ignored::key value
        #   # :::+
        #   # Another::key another value
        #
        #   Ignored::key value
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

          regexp = /^(.*?)::(:-|#{key})/
          while !scanner.eos?
            break if scanner.skip_until(regexp) == nil

            if scanner[2] == ":-"
              scanner.skip_until(/:::\+/)
            else
              next unless scanner[1] =~ CONSTANT_REGEXP
              key = scanner[2]
              yield($1.to_s, key, scanner.matched.strip) if scanner.scan(/[ \r\t].*$|$/)
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
                scanner.unscan unless $4 == '-' && $3 == key && $1.to_s == const_name
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
      
      # The source file for self, used during resolve.
      attr_reader :source_file
      
      # An array of Comment objects identifying lines 
      # resolved or to-be-resolved for self.
      attr_reader :comments
      
      # A hash of (const_name, attributes) pairs tracking the constant 
      # attributes resolved or to-be-resolved for self.  Attributes
      # are hashes of (key, comment) pairs.
      attr_reader :const_attrs
      
      # The default constant name used when no constant name
      # is specified for a constant attribute.
      attr_reader :default_const_name
      
      # Flag indicating whether or not self has been resolved.
      attr_accessor :resolved
      
      def initialize(source_file=nil, default_const_name='')
        self.source_file = source_file
        @default_const_name = default_const_name
        @comments = []
        @const_attrs = {}
        @resolved = false
        self.reset
      end
      
      # Resets self by clearing const_attrs, comments, and setting
      # resolved to false.  Generally NOT recommended as this 
      # clears any work you've done registering lines; to simply
      # allow resolve to re-scan a document, manually set
      # resolved to false.
      def reset
        @const_attrs.clear
        @comments.clear
        @resolved = false
        self
      end
      
      # Sets the source file for self.  Expands the source file path if necessary.
      def source_file=(source_file)
        @source_file = source_file == nil ? nil : File.expand_path(source_file)
      end
      
      # Sets the default_const_name for self.  Any const_attrs assigned to 
      # the previous default_const_name will be removed from const_attrs 
      # and merged with any const_attrs already assigned to the new 
      # default_const_name.
      def default_const_name=(const_name)
        self[const_name].merge!(const_attrs.delete(@default_const_name) || {})
        @default_const_name = const_name
      end
      
      # Returns the attributes for the specified const_name.
      def [](const_name)
        const_attrs[const_name] ||= {}
      end

      # Register the specified line number to self.  Returns a 
      # comment_class instance corresponding to the line.
      def register(line_number, comment_class=Comment)
        comment = comments.find {|c| c.class == comment_class && c.line_number == line_number }
        
        if comment == nil
          comment = comment_class.new(line_number)
          comments << comment
        end
        
        comment
      end
      
      def register_method(method, comment_class=Comment)
        register(/^\s*def\s+#{method}(\W|$)/, comment_class)
      end
      
      def resolve(str=nil)
        return(false) if resolved
        
        str = File.read(source_file) if str == nil
        Lazydoc.parse(str) do |const_name, key, comment|
          const_name = default_const_name if const_name.empty?
          self[const_name][key] = comment
        end
        
        unless comments.empty?
          lines = str.split(/\r?\n/)  
          comments.each do |comment|
            comment.resolve(lines)
          end
        end
        
        @resolved = true
      end
      
      def to_hash
        const_hash = {}
        const_attrs.each_pair do |const_name, attributes|
          next if attributes.empty?
          
          attr_hash = {}
          attributes.each_pair do |key, comment|
            attr_hash[key] = (block_given? ? yield(comment) : comment)
          end
          const_hash[const_name] = attr_hash
        end
        const_hash
      end
    end
  end
end
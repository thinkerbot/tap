require 'strscan'

module Tap
  module Support 
    module Lazydoc
      # Comment represents a code comment parsed by Lazydoc.  Comments consist
      # of a subject and content.
      #   
      #   sample_comment = %Q{
      #   # this is the content
      #   #
      #   # content may stretch across
      #   # multiple lines
      #   this is the subject
      #   }
      #   
      # Normally the subject is the first non-comment line following the content,
      # although in some cases the subject will be manually set to something else
      # (as in a Lazydoc constant attribute). The content is an array of comment
      # fragments organized by line:
      #
      #   c = Comment.parse(sample_comment)
      #   c.subject      # => "this is the subject"
      #   c.content      
      #   # => [
      #   # ["this is the content"], 
      #   # [""], 
      #   # ["content may stretch across", "multiple lines"]]
      #
      # Comments may be initialized to the subject line and then resolved later:
      #
      #   document = %Q{
      #   module Sample
      #     # this is the content of the comment
      #     # for method_one
      #     def method_one
      #     end
      #
      #     # this is the content of the comment
      #     # for method_two
      #     def method_two
      #     end
      #   end}
      #
      #   c1 = Comment.new(4).resolve(lines)
      #   c1.subject     # => "  def method_one"
      #   c1.content     # => [["this is the content of the comment", "for method_one"]]
      #
      #   c2 = Comment.new(9).resolve(lines)
      #   c2.subject     # => "  def method_two"
      #   c2.content     # => [["this is the content of the comment", "for method_two"]]
      # 
      # A Regexp (or Proc) may be used in place of a line number; during resolve,
      # the lines will be scanned and the first matching line will be used.
      #
      #   c3 = Comment.new(/def method_two/).resolve(lines)
      #   c3.subject     # => "  def method_two"
      #   c3.content     # => [["this is the content of the comment", "for method_two"]]
      #
      class Comment
    
        class << self
      
          # Parses the input string into a comment.  Takes a string or a 
          # StringScanner and returns the comment.
          #
          #   comment_string = %Q{
          #   # comments spanning multiple
          #   # lines are collected
          #   #
          #   #   while indented lines
          #   #   are preserved individually
          #   #    
          #   this is the subject line
          #
          #   # this line is not parsed
          #   }
          #
          #   c = Comment.parse(comment_string)
          #   c.content   
          #   # => [
          #   # ['comments spanning multiple', 'lines are collected'],
          #   # [''],
          #   # ['  while indented lines'],
          #   # ['  are preserved individually'],
          #   # [''],
          #   # []]
          #   c.subject   # => "this is the subject line"
          #
          # Parsing may be manually ended by providing a block; parse yields
          # each line fragment to the block and stops parsing when the block
          # returns true.  Note that no subject will be parsed under these
          # circumstances.
          #
          #   c = Comment.parse(comment_string) {|frag| frag.strip.empty? }
          #   c.content   
          #   # => [
          #   # ['comments spanning multiple', 'lines are collected']]
          #   c.subject   # => nil
          #
          # Subject parsing may also be suppressed by setting parse_subject
          # to false.
          def parse(str, parse_subject=true) # :yields: fragment
            scanner = case str
            when StringScanner then str
            when String then StringScanner.new(str)
            else raise TypeError, "can't convert #{str.class} into StringScanner or String"
            end
        
            comment = Comment.new
            while scanner.scan(/\r?\n?[ \t]*#[ \t]?(([ \t]*).*?)\r?$/)
              fragment = scanner[1]
              indent = scanner[2]
            
              # collect continuous description line
              # fragments and join into a single line
              if block_given? && yield(fragment)
                # break on comment if the description end is reached
                parse_subject = false
                break
              else
                categorize(fragment, indent) {|f| comment.push(f) }
              end
            end
        
            if parse_subject
              scanner.skip(/\s+/)
              unless scanner.peek(1) == '#'
                comment.subject = scanner.scan(/.+?$/) 
                comment.subject.strip! unless comment.subject == nil
              end
            end
        
            comment
          end
        
          # Scan determines if and how to add a line fragment to a comment and
          # yields the appropriate fragments to the block.  Returns true if
          # fragments are yielded and false otherwise.  
          #
          # Content may be built from an array of lines using scan like so:
          #
          #   lines = [
          #     "# comments spanning multiple",
          #     "# lines are collected",
          #     "#",
          #     "#   while indented lines",
          #     "#   are preserved individually",
          #     "#    ",
          #     "not a comment line",
          #     "# skipped since the loop breaks",
          #     "# at the first non-comment line"]
          #
          #   c = Comment.new
          #   lines.each do |line|
          #     break unless Comment.scan(line) do |fragment|
          #       c.push(fragment)  
          #     end
          #   end
          #
          #   c.content   
          #   # => [
          #   # ['comments spanning multiple', 'lines are collected'],
          #   # [''],
          #   # ['  while indented lines'],
          #   # ['  are preserved individually'],
          #   # [''],
          #   # []]
          #
          def scan(line) # :yields: fragment
            return false unless line =~ /^[ \t]*#[ \t]?(([ \t]*).*?)\r?$/
            categorize($1, $2) do |fragment|
              yield(fragment)
            end
            true
          end
        
          # Splits a line of text along whitespace breaks into fragments of cols
          # width.  Tabs in the line will be expanded into tabsize spaces; 
          # fragments are rstripped of whitespace.
          # 
          #   Comment.wrap("some line that will wrap", 10)       # => ["some line", "that will", "wrap"]
          #   Comment.wrap("     line that will wrap    ", 10)   # => ["     line", "that will", "wrap"]
          #   Comment.wrap("                            ", 10)   # => []
          #
          # The wrapping algorithm is slightly modified from:
          # http://blog.macromates.com/2006/wrapping-text-with-regular-expressions/
          def wrap(line, cols=80, tabsize=2)
            line = line.gsub(/\t/, " " * tabsize) unless tabsize == nil
            line.gsub(/(.{1,#{cols}})( +|$\r?\n?)|(.{1,#{cols}})/, "\\1\\3\n").split(/\s*?\n/)
          end
        
          private
        
          # utility method used by scan to categorize and yield
          # the appropriate objects to add the fragment to a
          # comment
          def categorize(fragment, indent) # :nodoc:
            case
            when fragment == indent
              # empty comment line
              yield [""]
              yield []
            when indent.empty?
              # continuation line
              yield fragment.rstrip
            else 
              # indented line
              yield [fragment.rstrip]
              yield []
            end
          end
        end
    
        # An array of comment fragments organized into lines
        attr_reader :content
    
        # The subject of the comment (normally set to the next 
        # non-comment line after the content ends; ie the line 
        # that would receive the comment in RDoc documentation)
        attr_accessor :subject
      
        # Returns the line number for the subject line, if known.
        # Although normally an integer, line_number may be
        # set to a Regexp or Proc to dynamically determine
        # the subject line during resolve
        attr_accessor :line_number
      
        def initialize(line_number=nil)
          @content = []
          @subject = nil
          @line_number = line_number
        end
        
        # Alias for subject
        def value
          subject
        end
        
        # Alias for subject=
        def value=(value)
          self.subject = value
        end

        # Pushes the fragment onto the last line array of content.  If the
        # fragment is an array itself then it will be pushed onto content 
        # as a new line.
        #
        #   c = Comment.new
        #   c.push "some line"
        #   c.push "fragments"
        #   c.push ["a", "whole", "new line"]
        #
        #   c.content         
        #   # => [
        #   # ["some line", "fragments"], 
        #   # ["a", "whole", "new line"]]
        #
        def push(fragment)
          content << [] if content.empty?
        
          case fragment
          when Array
            if content[-1].empty? 
              content[-1] = fragment
            else
              content.push fragment
            end
          else
             content[-1].push fragment
          end
        end
      
        # Alias for push.
        def <<(fragment)
          push(fragment)
        end
      
        # Scans the comment line using Comment.scan and pushes the appropriate
        # fragments onto self.  Used to build a content by scanning down a set
        # of lines.
        #
        #   lines = [
        #     "# comment spanning multiple",
        #     "# lines",
        #     "#",
        #     "#   indented line one",
        #     "#   indented line two",
        #     "#    ",
        #     "not a comment line"]
        #
        #   c = Comment.new
        #   lines.each {|line| c.append(line) }
        #
        #   c.content 
        #   # => [
        #   # ['comment spanning multiple', 'lines'],
        #   # [''],
        #   # ['  indented line one'],
        #   # ['  indented line two'],
        #   # [''],
        #   # []]
        #
        def append(line)
          Comment.scan(line) {|f| push(f) }
        end
      
        # Unshifts the fragment to the first line array of content.  If the
        # fragment is an array itself then it will be unshifted onto content
        # as a new line.
        #
        #   c = Comment.new
        #   c.unshift "some line"
        #   c.unshift "fragments"
        #   c.unshift ["a", "whole", "new line"]
        #
        #   c.content         
        #   # => [
        #   # ["a", "whole", "new line"], 
        #   # ["fragments", "some line"]]
        #
        def unshift(fragment)
          content << [] if content.empty?
        
          case fragment
          when Array
            if content[0].empty? 
              content[0] = fragment
            else
              content.unshift fragment
            end
          else
             content[0].unshift fragment
          end
        end
      
        # Scans the comment line using Comment.scan and unshifts the appropriate 
        # fragments onto self.  Used to build a content by scanning up a set of
        # lines.
        #
        #   lines = [
        #     "# comment spanning multiple",
        #     "# lines",
        #     "#",
        #     "#   indented line one",
        #     "#   indented line two",
        #     "#    ",
        #     "not a comment line"]
        #
        #   c = Comment.new
        #   lines.reverse_each {|line| c.prepend(line) }
        #
        #   c.content 
        #   # => [
        #   # ['comment spanning multiple', 'lines'],
        #   # [''],
        #   # ['  indented line one'],
        #   # ['  indented line two'],
        #   # ['']]
        #
        def prepend(line)
          Comment.scan(line) {|f| unshift(f) }
        end
      
        # Builds the subject and content of self using lines; resolve sets
        # the subject to the line at line_number, and parses content up
        # from there.  Any previously set subject and content is overridden.  
        # Returns self.
        #
        #   document = %Q{
        #   module Sample
        #     # this is the content of the comment
        #     # for method_one
        #     def method_one
        #     end
        # 
        #     # this is the content of the comment
        #     # for method_two
        #     def method_two
        #     end
        #   end}
        #
        #   c = Comment.new 4
        #   c.resolve(document)
        #   c.subject     # => "  def method_one"
        #   c.content     # => [["this is the content of the comment", "for method_one"]]
        #
        # Lines may be an array or a string; string inputs are split into an
        # array along newline boundaries.
        #
        # === dynamic line numbers
        # The line_number used by resolve may be determined dynamically from
        # lines by setting line_number to a Regexp and Proc. In the case
        # of a Regexp, the first line matching the regexp is used:
        #
        #   c = Comment.new(/def method/)
        #   c.resolve(document)
        #   c.line_number = 4
        #   c.subject     # => "  def method_one"
        #   c.content     # => [["this is the content of the comment", "for method_one"]]
        #
        # Procs are called with lines and are expected to return the
        # actual line number.  
        #
        #   c = Comment.new lambda {|lines| 9 }
        #   c.resolve(document)
        #   c.line_number = 9
        #   c.subject     # => "  def method_two"
        #   c.content     # => [["this is the content of the comment", "for method_two"]]
        #
        # As shown in the examples, in both cases the dynamically determined
        # line_number overwrites the Regexp or Proc.
        def resolve(lines)
          lines = lines.split(/\r?\n/) if lines.kind_of?(String)
        
          # resolve late-evaluation line numbers
          n = case line_number
          when Regexp then match_index(line_number, lines)
          when Proc then line_number.call(lines)
          else line_number
          end
         
          # quietly exit if a line number was not found
          return self unless n.kind_of?(Integer)
          
          unless n < lines.length
            raise RangeError, "line_number outside of lines: #{line_number} (#{lines.length})"
          end
        
          self.line_number = n
          self.subject = lines[n]
          self.content.clear
        
          # remove whitespace lines
          n -= 1
          n -= 1 while n >=0 && lines[n].strip.empty?

          # put together the comment
          while n >= 0
            break unless prepend(lines[n])
            n -= 1
          end
         
          self
        end
      
        # Removes leading and trailing lines from content that are
        # empty ([]) or whitespace (['']).  Returns self.
        def trim
          content.shift while !content.empty? && (content[0].empty? || content[0].join.strip.empty?)
          content.pop   while !content.empty? && (content[-1].empty? || content[-1].join.strip.empty?)
          self
        end
      
        # True if all lines in content are empty.
        def empty?
          !content.find {|line| !line.empty?}
        end
      
        # Returns content as a string where line fragments are joined by
        # fragment_sep and lines are joined by line_sep. 
        def to_s(fragment_sep=" ", line_sep="\n", strip=true)
          lines = content.collect {|line| line.join(fragment_sep)}
        
          # strip leading an trailing whitespace lines
          if strip
            lines.shift while !lines.empty? && lines[0].empty?
            lines.pop while !lines.empty? && lines[-1].empty?
          end
        
          line_sep ? lines.join(line_sep) : lines
        end
      
        # Like to_s, but wraps the content to the specified number of cols
        # and expands tabs to tabsize spaces.
        def wrap(cols=80, tabsize=2, line_sep="\n", fragment_sep=" ", strip=true)
          lines = Comment.wrap(to_s(fragment_sep, "\n", strip), cols, tabsize)
          line_sep ? lines.join(line_sep) : lines
        end
      
        # Returns true if another is a Comment with the same
        # line_number, subject, and content as self
        def ==(another)
          another.kind_of?(Comment) && 
          self.line_number == another.line_number &&
          self.subject == another.subject &&
          self.content == another.content
        end
      
        private
      
        # utility method used to by resolve to find the index
        # of a line matching a regexp line_number.
        def match_index(regexp, lines) # :nodoc:
          lines.each_with_index do |line, index|
            return index if line =~ regexp
          end
          nil
        end
      end
    end
  end
end
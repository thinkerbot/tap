require 'strscan'

module Tap
  module Support 
    # Comment represents a comment parsed by TDoc.
    class Comment
    
      class << self
      
        # Parses the input string into a comment, stopping at end_regexp
        # or the first non-comment line.  Also parses the next non-comment
        # lines as the comment subject.  Takes a string or a StringScanner
        # and returns the new comment.
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
        #   # this line is not parsed as it
        #   # is after a non-comment line
        #   }
        #
        #   c = Comment.parse(comment_string)
        #   c.lines   
        #   # => [
        #   # ['comments spanning multiple', 'lines are collected'],
        #   # [''],
        #   # ['  while indented lines'],
        #   # ['  are preserved individually'],
        #   # [''],
        #   # []]
        #   c.subject   # => "this is the subject line"
        #
        def parse(str, parse_subject=true) # :yields: fragment
          scanner = case str
          when StringScanner then str
          when String then StringScanner.new(str)
          else raise TypeError, "can't convert #{str.class} into StringScanner or String"
          end
        
          comment = Comment.new
          while scanner.scan(/\r?\n?[ \t]*#[ \t]?(([ \t]*).*?)$/)
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
        
        # Scans the line checking if it is a comment.  If so, scan
        # yields the parse fragments to the block which correspond
        # to the type of comment input (continuation, indent, etc).
        # Returns true if the line is a comment, false otherwise.
        #
        # Scan may be used to build a comment from an array of lines:
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
        #       # c.unshift will also work if building in reverse
        #       c.push(fragment)  
        #     end
        #   end
        #
        #   c.lines   
        #   # => [
        #   # ['comments spanning multiple', 'lines are collected'],
        #   # [''],
        #   # ['  while indented lines'],
        #   # ['  are preserved individually'],
        #   # [''],
        #   # []]
        #
        def scan(line) # :yields: fragment
          return false unless line =~ /^[ \t]*#[ \t]?(([ \t]*).*?)$/
          categorize($1, $2) do |fragment|
            yield(fragment)
          end
          true
        end
        
        def wrap(lines, cols=80, tabsize=2)
          lines.collect do |line|
            line = line.gsub(/\t/, " " * tabsize) unless tabsize == nil
        
            if line.strip.empty? 
              line
            else
              # wrapping algorithm is slightly modified from 
              # http://blog.macromates.com/2006/wrapping-text-with-regular-expressions/
              line.gsub(/(.{1,#{cols}})( +|$\r?\n?)|(.{1,#{cols}})/, "\\1\\3\n").split(/\s*\n/)
            end
          end.flatten
        end
        
        private
        
        def categorize(fragment, indent)
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
    
      # An array of line fragment arrays.
      attr_reader :lines
    
      # The next non-comment line after the comment ends.
      # This is the line that would receive the comment
      # in RDoc documentation.
      attr_accessor :subject
      
      # Returns the line number for the subject line, if known.
      attr_accessor :line_number
    
      def initialize(line_number=nil)
        @lines = []
        @subject = nil
        @line_number = line_number
      end
      
      def summary
        subject.to_s =~ /#(.*)$/ ? $1.strip : ""
      end

      # Pushes the fragment onto the last line array.  If fragment is an
      # array itself, then fragment will be pushed onto lines.
      #
      #   c = Comment.new
      #   c.push "some line"
      #   c.push "fragments"
      #   c.push ["a", "whole", "new line"]
      #   c.lines         # => [["some line", "fragments"], ["a", "whole", "new line"]]
      #
      def push(fragment)
        lines << [] if lines.empty?
        
        case fragment
        when Array
          if lines[-1].empty? 
            lines[-1] = fragment
          else
            lines.push fragment
          end
        else
           lines[-1].push fragment
        end
      end
      
      # Alias for push.
      def <<(fragment)
        push(fragment)
      end
      
      # Unshifts the fragment to the first line array.  If fragment is an
      # array itself, then fragment will be unshifted onto lines.
      #
      #   c = Comment.new
      #   c.unshift "some line"
      #   c.unshift "fragments"
      #   c.unshift ["a", "whole", "new line"]
      #   c.lines         # => [["a", "whole", "new line"], ["fragments", "some line"]]
      #
      def unshift(fragment)
        lines << [] if lines.empty?
        
        case fragment
        when Array
          if lines[0].empty? 
            lines[0] = fragment
          else
            lines.unshift fragment
          end
        else
           lines[0].unshift fragment
        end
      end
      
      def prepend(comment_line)
        Comment.scan(comment_line) {|f| unshift(f) }
      end
      
      def append(comment_line)
        Comment.scan(comment_line) {|f| push(f) }
      end
      
      # Removes leading and trailing lines that are empty ([]) 
      # or whitespace (['']).  Returns self.
      def trim
        lines.shift while !lines.empty? && (lines[0].empty? || lines[0].join.strip.empty?)
        lines.pop while !lines.empty? && (lines[-1].empty? || lines[-1].join.strip.empty?)
        self
      end
      
      # True if there are no fragments in self.
      def empty?
        !lines.find {|array| !array.empty?}
      end
    
      # Returns lines as a string where line fragments are joined by
      # fragment_sep and lines are joined by line_sep.  If cols is
      # specified, each line will be wrapped with the specified
      # number of columns.  If tabsize is specified, tabs will be
      # resolved to tabsize spaces.
      def to_s(fragment_sep=" ", line_sep="\n", cols=nil, tabsize=nil)
        resolved_lines = lines.collect do |line|
          line_str = line.join(fragment_sep)
          line_str = line_str.gsub(/\t/, " " * tabsize) unless tabsize == nil
        
          if cols == nil || line_str.strip.empty? 
            line_str
          else
            # wrapping algorithm is slightly modified from 
            # http://blog.macromates.com/2006/wrapping-text-with-regular-expressions/
            line_str.gsub(/(.{1,#{cols}})( +|$\r?\n?)|(.{1,#{cols}})/, "\\1\\3\n").split(/\s*\n/)
          end
        end.flatten
      
        line_sep ? resolved_lines.join(line_sep) : resolved_lines
      end
      
      def ==(another)
        another.kind_of?(Comment) && 
        self.line_number == another.line_number &&
        self.subject == another.subject &&
        self.lines == another.lines
      end

    end
  end
end
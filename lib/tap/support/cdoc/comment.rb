require 'strscan'

module Tap
  module Support
    module CDoc
      
      # Comment represents a comment parsed by CDoc.
      class Comment
        
        class << self
          
          # Parses the input string into a comment, stopping at end_regexp
          # or the first non-comment line.  Takes a string or a StringScanner
          # and returns the new comment.
          #
          #   comment_string = %Q{
          #   # comments spanning multiple
          #   # lines are collected
          #   #
          #   #   while indented lines
          #   #   are preserved individually
          #   #    
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
          #
          def parse(str)
            scanner = case str
            when StringScanner then str
            when String then StringScanner.new(str)
            else raise ArgumentError, "expected StringScanner or String"
            end
            
            comment = self.new
            while scanner.scan(/\r?\n?[ \t]*#[ \t]?(([ \t]*).*?)$/)
              current = scanner[1]
              whitespace = scanner[2]
              
              # collect continuous description line
              # fragments and join into a single line
              case
              when block_given? && yield(current)
                # break if the description end is reached
                break
              when current == whitespace
                # empty comment line
                comment << [""]
                comment << []
              when whitespace.empty?
                # continuation line
                comment << current.rstrip
              else 
                # indented line
                comment << [current.rstrip]
                comment << []
              end
            end
            
            comment
          end
        end
        
        # An array of line fragment arrays.
        attr_reader :lines
        
        def initialize
          @lines = [[]]
        end

        # Adds the fragment to the last line array.  If fragment is an
        # array itself, then fragment will be pushed onto lines.
        #
        #   c = Comment.new
        #   c << "some line"
        #   c << "fragments"
        #   c << ["a", "whole", "new line"]
        #   c.lines         # => [["some line", "fragments"], ["a", "whole", "new line"]]
        #
        def <<(fragment)
          case fragment
          when Array
            if lines[-1].empty? 
              lines[-1] = fragment
            else
              lines << fragment
            end
          else
             lines[-1] << fragment
          end
        end
        
        # Removes leading and trailing lines that are empty ([]) 
        # or whitespace (['']).  Returns self.
        def trim
          lines.shift while !lines.empty? && (lines[0].empty? || lines[0].join.strip.empty?)
          lines.pop while !lines.empty? && (lines[-1].empty? || lines[-1].join.strip.empty?)
          
          lines << [] if lines.empty?
          self
        end
        
        # Returns lines as a string where line fragments are joined by
        # fragment_sep and lines are joined by line_sep.  If cols is
        # specified, each line will be wrapped with the specified
        # number of columns.  If tabsize is specified, tabs will be
        # resolved to tabsize spaces.
        def to_s(fragment_sep=" ", line_sep="\n", cols=nil, tabsize=nil)
          lines.collect do |line|
            line_str = line.join(fragment_sep)
            line_str = line_str.gsub(/\t/, " " * tabsize) unless tabsize == nil
            
            if cols == nil || line_str.strip.empty? 
              line_str
            else
              # wrapping algorithm is slightly modified from 
              # http://blog.macromates.com/2006/wrapping-text-with-regular-expressions/
              line_str.gsub(/(.{1,#{cols}})( +|$\r?\n?)|(.{1,#{cols}})/, "\\1\\3\n").split(/\s*\n/)
            end
          end.flatten.join(line_sep)
        end
      end
    end
  end
end
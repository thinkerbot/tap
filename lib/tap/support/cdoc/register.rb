require 'tap/support/cdoc/comment'

module Tap
  module Support
    module CDoc
      class Register
        class << self
          
          # Keyifies the input by expanding (using File#expand_path)
          # and symbolizing.  Returns symbol inputs directly.
          def key(source_file)
            case source_file 
            when Symbol then source_file
            else File.expand_path(source_file).to_sym
            end
          end
        end
        
        # A hash of (source_file, [Comment]) pairs that
        # tracks which lines are registered for documentation
        # for the given source file.  Source file keys are
        # keyified using Register#key.
        attr_reader :registry

        def initialize
          @registry = {}
        end
        
        # Returns the registered comments for source_file
        def comments(source_file)
          registry[Register.key(source_file)] ||= []
        end
        
        # Register the specified line numbers to source_file.
        # Returns a Comment object corresponding to the line.
        def register(source_file, line_number)
          key = Register.key(source_file)
          comments = comments(key)
          comment = comments.find {|c| c.line_number == line_number }
  
          if comment == nil
            comment = Comment.new(line_number)
            comments << comment
          end

          comment
        end
        
        # Returns true if the comments for source_file are frozen.
        def resolved?(source_file)
          comments(source_file).frozen?
        end
        
        def resolve(source_file, str=nil)
          comments = comments(source_file)
          return comments if resolved?(source_file)
          
          str = File.read(source_file.to_s) if str == nil
          lines = str.split(/\r?\n/)
          
          comments.collect! do |comment|
            line_number = comment.line_number
            comment.target_line = lines[line_number]
            
            # remove whitespace lines
            line_number -= 1
            while lines[line_number].strip.empty?
              line_number -= 1
            end
          
            # put together the comment
            while line_number > 0
              break unless comment.prepend(lines[line_number])
              line_number -= 1
            end
            
            comment
          end.freeze
        end
        
      end
    end
  end
end

require 'tap/support/lazydoc/comment'

module Tap
  module Support
    module Lazydoc
      class Document
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
        
        # Returns an array of the const_names in self with at
        # least one attribute.
        def const_names
          names = []
          const_attrs.each_pair do |const_name, attrs|
            names << const_name unless attrs.empty?
          end
          names
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
end
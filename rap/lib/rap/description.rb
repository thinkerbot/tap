module Rap
  
  # :::-
  # A special type of Lazydoc::Comment designed to handle the comment syntax
  # for task declarations.
  #
  # Description instances can be assigned a description, or they may parse
  # one directly from the comment.  Comment lines with the constant attribute
  # '::desc' will have the value set as desc.
  # :::+
  class Description < Lazydoc::Comment
    
    # The description for self.
    attr_accessor :desc
    
    # Parses in-comment descriptions from prepended lines, if present.
    def prepend(line)
      if line =~ /::desc\s+(.*?)\s*$/
        self.desc = $1
        false
      else
        super
      end
    end
    
    # Resolves and returns the description.
    def to_s
      resolve
      desc.to_s
    end
  end
end
module Rap
  # A special type of Lazydoc::Comment designed to handle the comment syntax
  # for task declarations.
  class Description < Lazydoc::Comment
    attr_accessor :desc
    
    def prepend(line)
      if line =~ /::desc\s+(.*?)\s*$/
        self.desc = $1
        false
      else
        super
      end
    end
    
    def to_s
      resolve
      desc.to_s
    end
  end
end
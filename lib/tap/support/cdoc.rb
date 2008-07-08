require 'tap/support/cdoc/comment'

module Tap
  module Support
    module CDoc
      
      module_function
      
      # $1:: namespace
      # $3:: key
      CDOC_REGEXP = /(::|([A-Z][A-z]*::)+)([a-z_]+)/
      
      def scan(str, key)
        scanner = case str
        when StringScanner then str
        when String then StringScanner.new(str)
        else raise ArgumentError, "expected StringScanner or String"
        end
        
        regexp = /(::|([A-Z][A-z]*::)+)(#{key})([ \t].*)?$/
        
        while !scanner.eos?
          break if scanner.skip_until(regexp) == nil
          yield(scanner[1].chomp('::'), scanner[3], scanner[4].to_s.strip)
        end
        
        scanner
      end
      
      def parse(str) # :yields: namespace, key, value, comment
        scanner = case str
        when StringScanner then str
        when String then StringScanner.new(str)
        else raise ArgumentError, "expected StringScanner or String"
        end
        
        while !scanner.eos?
          break unless scanner.skip_until(CDOC_REGEXP)
          
          namespace = scanner[1].chomp('::')
          key = scanner[3]
          value = scanner.scan_until(/$/).strip
          comment = Comment.parse(scanner) do |comment|
            if comment =~ CDOC_REGEXP
              # rewind to capture the next comment unless
              # an end is specified.
              unless comment =~ /#{namespace}::#{key}-end/
                scanner.pos = scanner.pos - comment.length
              end
              true
            else false
            end
          end

          yield(namespace, key, value, comment)
        end
        
        scanner
      end  
      
    end
  end
end
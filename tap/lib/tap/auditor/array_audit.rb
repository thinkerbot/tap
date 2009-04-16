require 'tap/auditor/audit'

module Tap
  class Auditor
    class ArrayAudit < Audit
      
      # Converts audits with an array value to an array of audits, one for each
      # item in value.  The audits use the index of the item as a key and are
      # effectively forks of the present audit.
      #
      #   _a = ArrayAudit.new(nil, [:x, :y, :z])
      #   _b,_c,_d = _a.to_ary
      #
      #   _b.key                            # => 0
      #   _b.value                          # => :x
      #
      #   _c.key                            # => 1
      #   _c.value                          # => :y
      #
      #   _d.key                            # => 2
      #   _d.value                          # => :z
      #   _d.trail                          # => [_a,_d]
      #
      # Non-array values are converted to arrays using to_ary.  Raises an error
      # if value does not respond to 'to_ary'.
      def to_ary
        collection = []
        index = 0
        value.to_ary.each do |obj|
          collection << Audit.new(index, obj, self)
          index += 1
        end
        collection
      end
    end
  end
end
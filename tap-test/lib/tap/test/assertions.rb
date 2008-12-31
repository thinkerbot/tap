require 'tap/test/utils'

module Tap
  module Test
    module Assertions
      def assert_output_equal(a, b, msg=nil)
        a = a[1..-1] if a[0] == ?\n
        if a == b
          assert true
        else
          flunk %Q{
#{msg}
==================== expected output ====================
#{Utils.whitespace_escape(a)}
======================== but was ========================
#{Utils.whitespace_escape(b)}
=========================================================
}
        end
      end

      def assert_alike(a, b, msg=nil)
        if b =~ a
          assert true
        else
          flunk %Q{
#{msg}
================= expected output like ==================
#{Utils.whitespace_escape(a)}
======================== but was ========================
#{Utils.whitespace_escape(b)}
=========================================================
}
        end
      end
    end
  end
end
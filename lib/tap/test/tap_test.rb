module Tap
  module Test

    # Tap-specific testing methods to help with testing Tasks, such as the
    # checking of audits and test-specific modification of application 
    # configuration.
    #
    # === Class Methods
    # 
    # See {Test::Unit::TestCase}[link:classes/Test/Unit/TestCase.html] for documentation of the class methods added by TapTest.
    module TapTest
      
      # Returns the test-method-specific application.
      attr_reader :app
      
      # Setup creates a test-method-specific application that is initialized
      # to the method_root, and uses the relative and absolute paths from
      # trs (the test root structure, see Tap::Test::FileTest). 
      #
      # Also makes sure Tap::App.instance returns the test method app.
      def setup
        super
        @app = Tap::App.new(app_config)
        Tap::App.instance = @app
      end
      
      # Asserts that an array of audits are all equal, basically feeding
      # each pair of audits to assert_audit_equal.
      def assert_audits_equal(expected, audits, msg=nil, &block)
        assert_equal expected.length, audits.length, "expected <#{expected.length}> audits, but was <#{audits.length}>"
        Utils.each_pair_with_index(expected, audits) do |exp, audit, index|
          assert_audit_equal(exp, audit, &block)
        end
      end
      
      # Asserts that an audit trail matches the expected trail.  By default
      # the expected trail should be composed of [key, value] arrays 
      # representing each audit, but a block may be provided to collect other
      # attributes.
      #
      # Simple assertion:
      #
      #   a = Audit.new(:a, 'a')
      #   b = Audit.new(:b, 'b', a)
      # 
      #   e = [[:a, 'a'], [:b, 'b']]
      #   assert_audit_equal(e, b)
      #
      # Assertion with merge:
      #
      #   a = Audit.new(:a, 'a')
      #   b = Audit.new(:b, 'b', a)
      # 
      #   c = Audit.new(:c, 'c')
      #   d = Audit.new(:d, 'd', c)
      # 
      #   e = Audit.new(:e, 'e')
      #   f = Audit.new(:f, 'f', [b,d])
      # 
      #   eb = [[:a, "a"], [:b, "b"]]
      #   ed = [[:c, "c"], [:d, "d"]]
      #   e =  [[eb, ed], [:e, "e"], [:f, "f"]]
      # 
      #   assert_audit_equal(e, c)
      #
      def assert_audit_equal(expected, audit, msg=nil, &block)
        block = lambda {|audit| [audit.key, audit.value] } unless block
        actual = audit.trail(&block)
        assert_equal(expected, actual, msg)
      end
      
      # The configurations used to initialize self.app
      def app_config
        method_root.config.to_hash.merge(:quiet => true, :debug => true)
      end
      
      # Reconfigures app with the input configurations for the 
      # duration of the block.
      #
      #   app = Tap::App.new(:quiet => true, :debug => false)
      #   with_config({:quiet => false}, app) do 
      #     app.quiet                    # => false
      #     app.debug                    # => false
      #   end
      #
      #   app.quiet                      # => true
      #   app.debug                      # => false
      #
      def with_config(config={}, app=self.app, &block)
        begin
          hold = app.config.to_hash
          
          app.reconfigure(config)
          
          yield block if block_given?
        ensure
          app.send(:initialize_config, hold)
        end
      end
      
    end
  end
end





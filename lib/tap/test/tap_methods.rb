require 'test/unit'
require 'tap/test/file_methods'
require 'tap/test/subset_methods'

module Test # :nodoc:
  module Unit # :nodoc:
    class TestCase
      class << self
        # Causes a unit test to act as a tap test -- resulting in the following:
        # - setup using acts_as_file_test
        # - inclusion of Tap::Test::SubsetMethods
        # - inclusion of Tap::Test::InstanceMethods 
        #
        # Note:  Unless otherwise specified, <tt>acts_as_tap_test</tt> infers a root directory
        # based on the calling file. Be sure to specify the root directory explicitly 
        # if you call acts_as_file_test from a file that is NOT meant to be test file.
        def acts_as_tap_test(options={})
          options = options.inject({:root => file_test_root}) do |hash, (key, value)|
            hash[key.to_sym || key] = value
            hash
          end
          acts_as_file_test(options)
          
          include Tap::Test::SubsetMethods
          include Tap::Test::TapMethods
        end
        
      end
    end
  end
end

module Tap
  module Test

    # Used during check_audit to hold the sources and values of an audit
    # in the correct order.  Oriented so that the next value to be checked
    # is at the top of the stack.  Used internally.
    class AuditStack # :nodoc:
      attr_reader :test
    
      def initialize(test)
        @test = test
        @stack = []
      end
    
      def load_audit(values)
        [values._sources, values._values].transpose.reverse_each do |sv|
          load(*sv)
        end
      end
    
      def load(source, value)
        @stack.unshift [source, value]
      end
    
      def next
        @stack.shift
      end
    end

    # Tap-specific testing methods to help with testing Tasks, such as the
    # checking of audits and test-specific modification of application 
    # configuration.
    #
    # === Class Methods
    # 
    # See {Test::Unit::TestCase}[link:classes/Test/Unit/TestCase.html] for documentation of the class methods added by TapMethods.
    module TapMethods
      
      # Returns the test-method-specific application.
      attr_reader :app
      
      # Setup creates a test-method-specific application that is initialized
      # to the method_root, and uses the directories and absolute paths from
      # trs (the test root structure, see Tap::Test::FileMethods). 
      #
      # Also makes sure Tap::App.instance returns the test method app.
      def setup
        super
        @app = Tap::App.new(app_config)
        Tap::App.instance = @app
      end
      
      #
      # audit test methods
      #
      
      # Used to define expected audits in Tap::Test::TapMethods#assert_audit_equal
      class ExpAudit < Array
      end
      
      # Used to define merged audit trails in Tap::Test::TapMethods#assert_audit_equal
      class ExpMerge < Array
      end
      
      # Asserts that an array of audits are all equal, basically feeding
      # each pair of audits to assert_audit_equal.
      def assert_audits_equal(expected, audits)
        each_pair_with_index(expected, audits) do |exp, audit, index|
          assert_audit_equal(exp, audit, [index])
        end
      end
      
      # Asserts that an audit is as expected.  The expected audit should
      # be an ExpAudit (just a subclass of Array) that records the sources
      # and the values at each step in the audit trail.  Proc objects can
      # be provided in place of expected records that are hard or impossible 
      # to provide directly; the Proc will be used to validate the actual
      # record.  Merges must be marked in the ExpAudit using ExpMerge.
      #
      # Simple assertion:
      #
      #   a = Tap::Support::Audit.new
      #   a._record(:a, 'a')
      #   a._record(:b, 'b')
      # 
      #   e = ExpAudit[[:a, 'a'], [:b, 'b']]
      #   assert_audit_equal(e, a)
      # 
      # Assertion validating a record with a Proc (any number of
      # records can be validated with a Proc):
      #
      #   a = Tap::Support::Audit.new
      #   a._record(:a, 'a')
      #   a._record(:b, 'b')
      # 
      #   e = ExpAudit[
      #        lambda {|source, value| source == :a && value == 'a'},
      #       [:b, 'b']]
      #   assert_audit_equal(e, a)
      #
      # Assertion with merge:
      #
      #   a = Tap::Support::Audit.new
      #   a._record(:a, 'a')
      #   a._record(:b, 'b')
      # 
      #   b = Tap::Support::Audit.new
      #   b._record(:c, 'c')
      #   b._record(:d, 'd')
      # 
      #   c = Tap::Support::Audit.merge(a,b)
      #   c._record(:e, 'e')
      #   c._record(:f, 'f')
      # 
      #   ea = ExpAudit[[:a, "a"], [:b, "b"]]
      #   eb = ExpAudit[[:c, "c"], [:d, "d"]]
      #   e = ExpAudit[ExpMerge[ea, eb], [:e, "e"], [:f, "f"]]
      # 
      #   assert_audit_equal(e, c)
      #
      # When assert_audit_equal fails, a string of indicies is provided
      # to help locate which record was unequal.  For instance in the last
      # example, say we used:
      #
      #   ea = ExpAudit[[:a, "a"], [:b, "FLUNK"]]
      #   eb = ExpAudit[[:c, "c"], [:d, "d"]]
      #   e = ExpAudit[ExpMerge[ea, eb], [:e, "e"], [:f, "f"]]
      #
      # The failure message will read something like 'unequal record 0:0:1' 
      # indicating it was e[0][0][1] that failed.  Working through it, 
      # remembering that ExpAudit and ExpMerge are just subclasses of 
      # Array:
      #
      #   e              # => ExpAudit[ExpMerge[ea, eb], [:e, "e"], [:f, "f"]]
      #   e[0]           # => ExpMerge[ea, eb]
      #   e[0][0]        # => ExpAudit[[:a, "a"], [:b, "FLUNK"]]
      #   e[0][0][1]     # => [:b, "FLUNK"]
      #
      def assert_audit_equal(expected, audit, nesting=[])
        actual = audit._collect_records {|source, value| [source, value]}
        assert_audit_records_equal(expected, actual, nesting)
      end
      
      private
      
      def assert_audit_records_equal(expected, actual, nesting=[])
        assert_equal ExpAudit, expected.class
        assert_equal expected.length, actual.length, "unequal number of records"
        
        expected.each_with_index do |exp_record, i|
          case exp_record
          when ExpMerge
            exp_record.each_with_index do |exp_audit, j|
              assert_audit_records_equal(exp_audit, actual[i][j], nesting + [i,j]) 
            end
          when Proc
            assert exp_record.call(*actual[i]), "unconfirmed record #{(nesting + [i]).join(':')}"
          else
            assert_equal exp_record, actual[i], "unequal record #{(nesting + [i]).join(':')}"
          end
        end
      end
      
      public
      
      # The configurations used to initialize self.app
      def app_config
        { :root => method_root, 
          :directories => trs.directories,
          :absolute_paths => trs.absolute_paths,
          :quiet => true, 
          :debug => true}
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





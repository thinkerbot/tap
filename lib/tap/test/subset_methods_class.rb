require 'tap/test/env_vars'

module Tap
  module Test
    module SubsetMethodsClass
      include Tap::Test::EnvVars
      
      # Passes conditions to subclass
      def inherited(subclass) # :nodoc:
        super
        subclass_conditions = conditions.inject({}) do |memo, (key, value)|
          memo.update(key => (value.dup rescue value))
        end
        subclass.instance_variable_set(:@conditions, subclass_conditions)
        subclass.instance_variable_set(:@run_test_suite, nil)
        subclass.instance_variable_set(:@skip_messages, [])
        
    #    subclass_inputs = prompt_inputs.inject({}) do |memo, (key, value)|
    #      memo.update(key => (value.dup rescue value))
    #    end
    #    subclass.instance_variable_set("@prompt_inputs", subclass_inputs)
      end
      
      # Experimental -- The idea is to provide a way to prompt once for inputs
      # that get used multiple times in a test.  Perhaps create accessors
      # automatically?
      
    #  def prompt_inputs
    #    @prompt_inputs ||= {}
    #  end
      
    #  def require_inputs(*keys, &block)
    #    if run_subset?("PROMPT")
    #      puts "\n#{name} requires inputs -- Enter values or 'skip'."
          
    #      argv = ARGV.dup
    #      begin
    #        ARGV.clear
    #        keys.collect do |key|
    #          print "#{key}: "
    #          value = gets.strip
    #          if value =~ /skip/i
    #            skip_test "missing inputs"
    #            break
    #          end
    #          prompt_inputs[key] = value
    #        end
    #      ensure
    #        ARGV.clear
    #        ARGV.concat(argv)
    #      end
    #    else
    #      skip_test "prompt test"
    #    end
    #  end 
      
      #
      # conditions
      #

      # A hash of defined conditions
      def conditions
        @conditions ||= {}
      end
    
      # Defines a condition block and associated message.  
      # Raises an error if no condition block is given.
      def condition(name, msg=nil, &block)
        raise "no condition block given" unless block_given?
        conditions[name.to_sym] = [msg, block]
      end
      
      # Returns true if the all blocks for the named conditions return true.
      #
      #   condition(:is_true) { true }
      #   condition(:is_false) { false }
      #   satisfied?(:is_true)              # => true
      #   satisfied?(:is_true, :is_false)   # => false
      #
      def satisfied?(*conditions)
        unsatisfied_conditions(*conditions).empty?
      end
        
      # Returns an array of the unsatified conditions.  Raises 
      # an error if the named condition has not been defined.
      #
      #   condition(:is_true) { true }
      #   condition(:is_false) { false }
      #   unsatisfied_conditions(:is_true, :is_false)   # => [:is_false]
      #
      def unsatisfied_conditions(*conditions)
        conditions = self.conditions.keys if conditions.empty?
        unsatified = []
        conditions.each do |condition|
          raise "Unknown condition: #{condition}" unless self.conditions.has_key?(condition)
          unsatified << condition unless (self.conditions[condition.to_sym].last.call() ? true : false)
        end
        unsatified
      end
      
      # Returns true if RUBY_PLATFORM matches one of the specfied
      # platforms.  Use the prefix 'non_' to specify any plaform 
      # except the specified platform (ex: 'non_mswin').  Returns
      # true if no platforms are specified.
      #
      # Some common platforms:
      #   mswin    Windows
      #   darwin   Mac
      def match_platform?(*platforms)
        platforms.each do |platform|
          platform.to_s =~ /^(non_)?(.*)/

          non = true if $1
          match_platform = !RUBY_PLATFORM.index($2).nil?
          return false unless (non && !match_platform) || (!non && match_platform)
        end

        true
      end
      
      # Returns true if the subset type or 'ALL' is specified in ENV
      def run_subset?(type)
        env_true?(type) || env_true?("ALL") ? true : false
      end
    end
    
  end
end
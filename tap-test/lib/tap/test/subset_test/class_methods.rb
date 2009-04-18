module Tap
  module Test
    module SubsetTest
      
      # Class methods associated with SubsetTest.
      module ClassMethods
        
        # Passes conditions to subclass
        def inherited(child) # :nodoc:
          super
          dup = {}
          conditions.each_pair {|key, value| dup[key] = value.dup }
          child.instance_variable_set(:@conditions, dup)
        end
      
        # Initialize conditions.
        def self.extended(base) # :nodoc:
          base.instance_variable_set(:@conditions, {})
        end
      
        # A hash of [name, [msg, condition_block]] pairs defined by condition.
        attr_reader :conditions
    
        # Defines a condition block and associated message.  
        # Raises an error if no condition block is given.
        def condition(name, msg=nil, &block)
          raise ArgumentError, "no condition block given" unless block_given?
          conditions[name] = [msg, block]
        end
      
        # Returns true if the all blocks for the specified conditions return true.
        #
        #   condition(:is_true) { true }
        #   condition(:is_false) { false }
        #   satisfied?(:is_true)              # => true
        #   satisfied?(:is_true, :is_false)   # => false
        #
        # Yields the name and message for each unsatisfied condition to the
        # block, if given.
        def satisfied?(*names) # :yields: name-of-unsatisfied-condition, msg
          unsatisfied = unsatisfied_conditions(*names)
        
          unsatisfied.each do |name| 
            yield(name, condition[name][0])
          end if block_given?
          
          unsatisfied.empty?
        end
        
        # Returns an array of the unsatified conditions.  Raises 
        # an error if a condition has not been defined.
        #
        #   condition(:is_true) { true }
        #   condition(:is_false) { false }
        #   unsatisfied_conditions(:is_true, :is_false)   # => [:is_false]
        #
        def unsatisfied_conditions(*condition_names)
          condition_names = conditions.keys if condition_names.empty?
          unsatified = []
          condition_names.each do |name|
            unless condition = conditions[name]
              raise ArgumentError, "Unknown condition: #{name}"
            end
          
            unsatified << name unless condition.last.call
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
      
        # Returns true if type or 'ALL' is specified as 'true' in ENV.
        def run_subset?(type)
          ENV[type] == "true" || ENV['ALL'] == "true" ? true : false
        end
      end
    end
  end
end
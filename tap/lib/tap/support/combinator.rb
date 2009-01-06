require 'enumerator'

module Tap 
  module Support
    
    # Combinator provides a method for iterating over all combinations
    # of items in the input sets.
    #
    #   c = Combinator.new [1,2], [3,4]
    #   c.to_a            # => [[1,3], [1,4], [2,3], [2,4]]
    #
    # Combinators can take any object that responds to each as an
    # input set; normally arrays are used.
    #
    # === Implementation
    #
    # Combinator iteratively combines each element from the first set (a)
    # with each element from the second set (b).  When more than two sets
    # are given, the second and remaining sets are bundled into a
    # Combinator, which then acts as the second set.
    #
    #   c = Combinator.new [1,2], [3,4], [5,6]
    #   c.a               # => [[1],[2]]
    #   c.b.class         # => Combinator
    #   c.b.a             # => [[3],[4]]
    #   c.b.b             # => [[5],[6]]
    #
    # Note that internally each item in a set is stored as a single-item
    # array; the arrays are added during combination.  Thus when 
    # iterating, the combinations are calculated like:
    #
    #   ([1] + [3]) + [5] # => [1,3,5]
    #
    # This is surely not the fastest implementation, but it works.
    class Combinator
      include Enumerable
      
      # The first set
      attr_reader :a
      
      # The second set
      attr_reader :b

      # Creates a new Combinator.  Each input must respond
      # to each, or be nil.
      def initialize(*sets)
        @a = make_set(sets.shift)
        @b = make_set(*sets)
      end

      # Returns the sets used to initialize the Combinator.
      def sets
        sets_in(a) + sets_in(b)
      end

      # True if length is zero.
      def empty?
        a.empty? && b.empty?
      end

      # Returns the number of combinations returned by each.
      def length
        case
        when !(@a.empty? || @b.empty?)
          @a.length * @b.length
        when @a.empty? 
          @b.length
        when @b.empty?
          @a.length
        end
      end

      # Passes each combination as an array to the input block.
      def each # :yields: combination
        case
        when !(@a.empty? || @b.empty?)
          @a.each do |a|
            @b.each do |b|
              yield(a + b)
            end
          end
        when @a.empty? 
          @b.each {|b| yield(b) }
        when @b.empty? 
          @a.each {|a| yield(a) }
        end
      end

      private
      
      # makes a Combinator out of multiple sets or collects the
      # objects of a single set as arrays:
      #
      #   make_set([1,2,3], [4,5,6])  # => Combinator.new([1,2,3], [4,5,6])
      #   make_set([1,2,3])           # => [[1],[2],[3]]
      #
      def make_set(*sets) # :nodoc:
        # recieves an array of arrays or combinators
        return Combinator.new(*sets) if sets.length > 1 
        return sets if sets.empty?
        
        set = sets[0]
        return [] if set == nil
        
        unless set.respond_to?(:each)
          raise ArgumentError, "does not respond to each: #{set}"
        end
        
        # recursively arrayifies each element
        arrayified_set = []
        set.each {|s| arrayified_set << [s]}
        arrayified_set
      end

      # basically the reverse of make_set
      def sets_in(set) # :nodoc:
        case set
        when Combinator then set.sets
        when Array then set.empty? ? [] : [set.collect {|s| s[0]}]
        end
      end
      
    end
  end
end
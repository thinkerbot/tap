module Tap
  module Support
    class Combinator
      attr_reader :a, :b

      def initialize(*sets)
        @a = make_set(sets.shift)
        @b = make_set(*sets)
      end

      def sets
        sets_in(@a) + sets_in(@b)
      end

      def empty?
        @a.empty? && @b.empty?
      end

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

      def each
        case
        when !(@a.empty? || @b.empty?)
          @a.each do |*a|
            @b.each do |*b|
              yield(*(a + b))
            end
          end
        when @a.empty? 
          @b.each {|*b| yield(*b) }
        when @b.empty? 
          @a.each {|*a| yield(*a) }
        end
      end

      def collect
        cc = []
        each do |*c| 
          cc << (block_given? ? yield(*c) : c)
        end 
        cc
      end

      protected

      def sets_in(set)
        set.kind_of?(Array) ? (set.empty? ? [] : [set]) : set.sets
      end

      def make_set(*sets)
        return Combinator.new(*sets) if sets.length > 1 
        return [] if sets.empty?

        set = sets.first
        case set 
        when Combinator then set
        when Array then set
        when nil then []
        else [set]
        end
      end
    end
  end
end
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
        if @a.empty? || @b.empty?
          if !@a.empty?
            @a.length
          elsif !@b.empty?
            @b.length
          else
            0
          end
        else
          @a.length * @b.length
        end
      end

      def each(&block)
        if @a.empty? || @b.empty?
          if !@a.empty?
            @a.each do |*a|
              yield(*a) if block_given?
            end
          elsif !@b.empty?
            @b.each do |*b|
              yield(*b) if block_given?
            end
          end
        else
          @a.each do |*a|
            @b.each do |*b|
              yield(*(a + b)) if block_given?
            end
          end
        end
      end

      def collect(&block)
        cc = []
        self.each do |*c| 
          if block_given? 
            cc << yield(*c)
          else
            cc << c
          end
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
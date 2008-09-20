module Tap
  module Support
    class Node
      Join = Struct.new(:type, :targets, :options)

      attr_reader :argv
      attr_reader :source
      attr_reader :join

      def initialize
        @argv = []
        @source = nil
        @join = nil
      end
      
      def reset
        self.source = nil
        self.join = nil
      end

      def source=(input)
        # remove the join in the targets, if
        # necessary, to prevent scrambling
        @source.targets.each do |target|
          target.join = nil
        end if @source.kind_of?(Join)

        @source = input
      end

      def join=(input)
        @join = input

        # set the source of the targets      
        input.targets.each do |target|
          target.source = input
        end if input.kind_of?(Join)
      end
    end
  end
end
require 'tap/middleware'

module Tap
  module Middlewares
    
    # :startdoc::middleware profile the workflow execution time
    #
    #
    class Profiler < Tap::Middleware
      
      attr_reader :app_time
      attr_reader :nodes
      attr_reader :counts
      
      def initialize(stack, config={})
        super
        reset
        at_exit { app.quiet = false; app.log(:profile, "\n" + summary.join("\n")) }
      end
      
      def reset
        @app_time = 0
        @last = nil
        @nodes = Hash.new(0)
        @counts = Hash.new(0)
      end
      
      def total_time
        nodes.values.inject(0) {|sum, elapsed| sum + elapsed }
      end
      
      def total_counts
        counts.values.inject(0) {|sum, n| sum + n }
      end
      
      def call(node, inputs=[])
        @app_time += Time.now - @last if @last
        
        start = Time.now
        result = super
        elapsed = Time.now - start
        
        nodes[node] += elapsed
        counts[node] += 1
        
        @last = Time.now
        result
      end
      
      def summary
        lines = []
        lines << "App Time: #{app_time}s"
        lines << "Node Time: #{total_time}s"
        lines << "Nodes Run: #{total_counts}"
        lines << "Breakdown:"
        
        nodes_by_class = {}
        nodes.each_key do |node|
          (nodes_by_class[node.class.to_s] ||= []) << node
        end
        
        nodes_by_class.keys.sort.each do |node_class|
          nodes_by_class[node_class].each do |node|
            lines << "- #{node_class}: [#{nodes[node]}, #{counts[node]}]"
          end
        end
        
        lines
      end
    end
  end
end
require 'tap/joins'
require 'tap/schema/node'
autoload(:Shellwords, 'shellwords')

module Tap
  class Schema
    autoload(:Parser, 'tap/schema/parser')
    
    class << self
      def parse(argv=ARGV)
        Parser.new(argv).schema
      end

      def load(argv)
        parser = Parser.new
        parser.load(argv)
        parser.schema
      end
      
      # Loads a schema from the specified path.  Raises an error if no such
      # file existts.
      def load_file(path)
        argv = YAML.load_file(path)
        argv ? load(argv) : new
      end
    end
    
    # An array of the nodes in self.  Nodes may contain nils.
    attr_reader :nodes
    
    def initialize(nodes=[])
      @nodes = nodes
    end
    
    # Retrieves the node at index, or instantiates a new Node if one does
    # not already exists.
    def [](index)
      nodes[index] ||= Node.new
    end
    
    # Returns the index of the node in nodes.
    def index(node)
      nodes.index(node)
    end
    
    # Returns an array of the metadata for each nodes.
    def metadata
      nodes.collect do |node|
        node == nil ? nil : node.metadata
      end
    end
    
    # Returns the indicies of each node, or nil if nodes is nil.
    def indicies(nodes)
      nodes ? nodes.collect {|node| index(node) } : nodes
    end
    
    # Returns an array of joins among nodes in self.
    def joins
      joins = []
      
      nodes.each do |node|
        next unless node
        if join = node.output
          joins << join
        end
      end
      
      nodes.each do |node|
        next unless node
        if join = node.input
          joins << join
        end
      end
      
      joins.uniq
    end
    
    # Sets a join between the nodes at the input and output indicies.
    # Returns the new join.
    def set_join(inputs, outputs, argh={})
      join = Join.new [],[], argh
      
      inputs.each {|index| self[index].output = join }
      outputs.each {|index| self[index].input = join }
      
      join
    end
    
    # Removes all nil nodes, nodes with empty argvs, and orphaned joins.
    # Returns self.
    def cleanup
      # remove nil and empty nodes
      nodes.delete_if do |node|
        node == nil || node.empty?
      end
      
      # cleanup joins
      joins.each do |join|
        
        # remove missing output nodes
        join.outputs.delete_if {|node| !nodes.include?(node) }
        
        # remove missing input nodes
        join.inputs.delete_if {|node| !nodes.include?(node) }
        
        # detach if orphanded
        join.detach! if join.orphan?
      end
      
      self
    end
    
    # Creates an hash dump of self.
    def to_hash
      cleanup
      
      hash = {}
      hash[:nodes] = nodes.collect do |node|
        node.metadata
      end
      hash[:joins] = joins.collect do |join|
        metadata = join.metadata
        case metadata
        when Hash
          metadata.merge(
            :inputs => indicies(join.inputs),
            :outputs => indicies(join.outputs))
        when Array
          "[#{indicies(join.inputs.join(','))}][#{indicies(join.outputs.join(','))}]#{metadata.reverse.join('.')}"
        end
      end
      
      # hash[:middleware] = middleware.collect do |middleware| 
      #   middleware.metadata
      # end
      
      hash.delete_if {|key, value| value.empty? }
      hash
    end
    
    # Converts self to a hash and serializes it to YAML.
    def dump
      YAML.dump(to_hash)
    end
  end
end
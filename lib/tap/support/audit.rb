module Tap
  module Support
    
    # Audit provides a way to track the values passed among tasks or, more 
    # generally, any Executable.  Audits collectively build a directed
    # acyclic graph of task execution and have great utility in debugging
    # and record keeping.
    #
    # Audits record a key, a current value, and the previous audit(s) (ie
    # 'sources') in the trail.  Keys are arbitrary identifiers of where the
    # value comes from; to illustrate, lets use symbols as keys.
    #
    #   # initialize a new audit
    #   a = Audit.new(:one, 1)
    #   a.key                               # => :one
    #   a.value                             # => 1
    #
    #   # build a short trail
    #   b = Audit.new(:two, 2, a)
    #   c = Audit.new(:three, 3, b)
    #
    #   a.sources                           # => []
    #   b.sources                           # => [a]
    #   c.sources                           # => [b]
    #
    # Audits allow you track back through the sources of each node to build
    # an audit trail describing how a particular value was produced.
    #
    #   c._trail                            # => [a,b,c]
    #   c._trail {|audit| audit.key }       # => [:one, :two, :three]
    #   c._trail {|audit| audit.value }     # => [1,2,3]
    #
    # Any number of nodes may share the same source, so forks are naturally
    # supported.
    #
    #   d = Audit.new(:four, 4, b)
    #   d._trail                            # => [a,b,d]
    #
    #   e = Audit.new(:five, 5, b)
    #   e._trail                            # => [a,b,e]
    #
    # Merges are supported by specifying more than one source audit.  Merges
    # have the effect of nesting audit trails within an array:
    #
    #   f = Audit.new(:six, 6)
    #   g = Audit.new(:seven, 7, f)
    #   h = Audit.new(:eight, 8, [c,d,g])
    #   h._trail                            # => [[[a,b,c], [a,b,d], [f,g]], h]
    #   
    # Nesting can get quite ugly and impenetrable after a couple merges, but
    # Audit provides a scalable pretty-print to_s method that helps visualize
    # what is actually happening.
    #
    #   "\n" + h._to_s
    #   # => %q{
    #   # o-[one] 1
    #   # o-[two] 2
    #   # |
    #   # |-o-[three] 3
    #   # | |
    #   # `---o-[four] 4
    #   #   | |
    #   #   | | o-[six] 6
    #   #   | | o-[seven] 7
    #   #   | | |
    #   #   `-`-`-o-[eight] 8
    #   # }
    #
    # In practice, tasks are recorded as keys. Thus audit trails can be used
    # to access task configurations and other information that may be useful
    # when creating reports or making workflow decisions.
    #
    #--
    # Note Audit could easily be expanded to track sinks as well as sources.
    # In initialize:
    #
    #   @sinks = []
    #   sources.each do |source|
    #     source.sinks << self
    #   end
    # 
    # The downside is that this may not circumvent cleanly if you want light
    # or no auditing.  It also adds additonal references which will prevent
    # garbage collection.  On the plus side, sinks will make it easier to
    # truly use Audits as a DAG
    class Audit
      class << self
        
        # Produces a pretty-print dump of a series of nodes to target.  A
        # block may be provided to format the trailer of each line (which
        # is by default 'o-[key] value').
        #
        def dump(audits, target=$stdout) # :yields: audit
          return dump(audits, target) do |audit| 
            "o-[#{audit.key}] #{audit.value.inspect}"
          end unless block_given?
          
          # arrayify audits
          audits = [audits].flatten
          
          # the order of audits
          order = []
          
          # (audit, sinks) hash preventing double
          # iteration over audits, and identifying
          # sinks for a particular audit
          sinks = {}
          
          # iterate over all audits, collecting in order
          audits.each do |audit|
            traverse(audit, order, sinks)
          end
          
          # now visit each audit, collecting audits into indent groups
          groups = []
          group = nil
          order.each do |audit|
            sources = audit.sources
            unless sources.length == 1 && sinks[sources[0]].length <= 1
              group = []
              groups << group
            end
            
            group << audit
          end
          
          # identify nodes at which a fork occurs... these are audits
          # that have more than one sink, and they cause a fork-style
          # leader to be printed
          forks = {}
          sinks.each_pair do |audit, sinks|
            n = sinks.length
            forks[audit] = [0, n] if n > 1
          end
          
          # setup print
          index = 0
          leader = ""
          
          # print each group
          groups.each do |group|
            sources = group[0].sources
            complete = audits.include?(group[-1])
            
            case 
            when sources.length > 1
              # print a merge
              # `-`-`-o-[merge]
              
              leader =~ /^(.*)((\| *){#{sources.length}})$/
              leader = "#{$1}#{' ' * $2.length} "
              target << "#{$1}#{$2.gsub('|', '`').gsub(' ', '-')}-#{yield(group.shift)}\n"
              
            when fork = forks[sources[0]]
              # print a fork
              # |-o-[a]
              # |
              # `---o-[b]
              n = fork[0] += 1
              base = leader[0, leader.length - (2 * n - 1)]
              target << "#{base}#{fork[0] == fork[1] ? '`-' : '|-'}#{'--' * (n-1)}#{yield(group.shift)}\n"
              leader  = "#{base}#{fork[0] == fork[1] ? '  ' : '| '}#{'| ' * (n-1)}"
              
            when index > 0
              # simply get ready to print the next series of audits
              # o-[a]
              # o-[b]
              leader = "#{leader} "
              leader = "" if leader.strip.empty?
            end
            
            group.each do |audit|
              target << "#{leader}#{yield(audit)}\n"
            end
            
            # add a continuation line, if necessary
            unless group == groups.last
              if complete
                leader = "#{leader} "
              else
                leader = "#{leader}|"
              end
              target << "#{leader}\n"
            end
            
            index += 1
          end
          
          target
        end
        
        protected
        
        # helper to determine the order and sinks for a node.
        # used in dump
        def traverse(node, order=[], sinks={}) # :nodoc:
          return if sinks.has_key?(node)
          
          node.sources.each do |source|
            traverse(source, order, sinks)
            (sinks[source] ||= []) << node
          end
          
          order << node
        end
      end
      
      # A key for self (typically the task producing value, or
      # nil if the value has an unknown origin)
      attr_reader :key
      
      # The current value
      attr_reader :value
      
      def initialize(key=nil, value=nil, sources=nil)
        @key = key
        @value = value
        @source = singularize(sources)
      end
      
      # An array of source audits for self.
      def sources
        arrayify(@source)
      end
      
      # Produces a fork of self for each item in value, using the index of
      # the item as a key.  Iterate is useful for developing each item of
      # an array along different paths.
      #
      #   a = Audit.new(nil, [:x, :y, :z])
      #   b,c,d = a._iterate
      #
      #   b.key                       # => 0
      #   b.value                     # => :x
      #
      #   c.key                       # => 1
      #   c.value                     # => :y
      #
      #   d.key                       # => 2
      #   d.value                     # => :z
      #   d._trail                    # => [a,d]
      # 
      # If value does not respond to :each, an array with self as the only
      # member will be returned.  This ensures that the result of _iterate
      # is an array of audits ready for further development.
      # 
      #   a = Audit.new(nil, :value)
      #   a._iterate                  # => [a]
      #
      def _iterate
        return [self] unless value.respond_to?(:each)
        
        collection = []
        index = 0
        value.each do |obj|
          collection << Audit.new(index, obj, self)
          index += 1
        end
        collection
      end
      
      # Recursively collects an audit trail leading to self.  Single sources
      # are collected into a trail directly, while multiple sources are
      # collected into arrays.
      #
      #   a = Audit.new(:one, 1)
      #   b = Audit.new(:two, 2, a)
      #   b._trail                          # => [a, b]
      #
      #   a = Audit.new(:one, 1)
      #   b = Audit.new(:two, 2)
      #   c = Audit.new(:three, 3, [a, b])
      #   c._trail                          # => [[[a], [b]], c]
      #
      # A block may be provided to collect a specific attribute of audits
      # in the trail.
      #
      #   c._trail {|audit| audit.value }   # => [[[1], [2]], 3]
      #
      def _trail(trail=[], &block)
        trail.unshift(block_given? ? block.call(self) : self)
        
        case @source
        when Audit
          @source._trail(trail, &block)
        when Array
          trail.unshift @source.collect {|audit| audit._trail(&block) }
        end
        
        trail
      end
      
      # A kind of pretty-print for Audits.  See the documentation for
      # an example of the _to_s dump.
      def _to_s(&block)
        Audit.dump(self, "", &block)
      end
      
      private
      
      # helper to optimize storage of nodes
      def singularize(obj) # :nodoc:
        return obj unless obj.kind_of?(Array)
        
        case obj.length
        when 0 then nil
        when 1 then obj[0]
        else obj
        end
      end
      
      # helper to optimize storage of nodes
      def arrayify(obj) # :nodoc:
        case obj
        when nil then []
        when Array then obj
        else [obj]
        end
      end
    end
  end
end
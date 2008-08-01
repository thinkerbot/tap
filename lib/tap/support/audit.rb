module Tap
  module Support 
    
    # Marks the merge of multiple Audit trails
    class AuditMerge < Array
      def ==(another)
        another.kind_of?(AuditMerge) && super
      end
    end
    
    # Marks a split in an Audit trail
    class AuditSplit
      attr_reader :block
      def initialize(block) @block = block end
        
      def ==(another)
        another.kind_of?(AuditSplit) && another.block == block
      end
    end
    
    # Marks the expansion of an Audit trail
    class AuditExpand
      attr_reader :index
      def initialize(index) @index = index end
        
      def ==(another)
        another.kind_of?(AuditExpand) && another.index == index
      end
    end

    # == Overview
    #
    # Audit provides a way to track the values (inputs and results) passed
    # among tasks or, more generally, any Executable method.  Audits allow 
    # you to track inputs as they make their way through a workflow, and 
    # have great utility in debugging and record keeping. 
    #
    # During execution, the group of inputs for a task are used to initialize 
    # an Audit.  These inputs mark the begining of an audit trail; every 
    # task that processes them (including the first) adds to the trail by 
    # recording it's result using itself as the 'source' of the result.
    #
    # Since Audits are meant to be fairly general structures, they can take 
    # any object as a source, so for illustration lets use some symbols:
    #   
    #   # initialize a new audit
    #   a = Audit.new(1, nil)
    #
    #   # record some values
    #   a._record(:A, 2)
    #   a._record(:B, 3)
    #
    # Now you can pull up the source and value trails, as well as 
    # information like the current and original values:
    #
    #   a._source_trail      # => [nil, :A, :B]
    #   a._value_trail       # => [1, 2, 3]
    #
    #   a._original          # => 1
    #   a._original_source   # => nil
    #
    #   a._current           # => 3
    #   a._current_source    # => :B
    #
    # Merges are supported by using an array of the merging trails (internally
    # an AuditMerge) as the source, and an array of the merging values as the 
    # initial value.  
    #
    #   b = Audit.new(10, nil)
    #   b._record(:C, 11)
    #   b._record(:D, 12)  
    #
    #   c = Audit.merge(a, b)
    #   c._source_trail      # => [ [[nil, :A, :B], [nil, :C, :D]] ]
    #   c._value_trail       # => [ [[1,2,3], [10, 11, 12]] ]
    #   c._current           # => [3, 12]
    #
    #   c._record(:E, "a string value")
    #   c._record(:F, {'a' => 'hash value'})
    #   c._record(:G, ['an', 'array', 'value'])
    #
    #   c._source_trail      # => [ [[nil, :A, :B], [nil, :C, :D]], :E, :F, :G]
    #   c._value_trail       # => [ [[1,2,3], [10, 11, 12]], "a string value", {'a' => 'hash value'}, ['an', 'array', 'value']]
    #
    # Audit supports forks by duplicating the source and value trails.  Forks
    # can be developed independently.  Importantly, Audits are forked during 
    # a merge; notice the additional record in +a+ doesn't change the source 
    # trail for +c+:
    #
    #   a1 = a._fork
    #
    #   a._record(:X, -1)
    #   a1._record(:Y, -2)
    #
    #   a._source_trail      # => [nil, :A, :B, :X]
    #   a1._source_trail     # => [nil, :A, :B, :Y]
    #   c._source_trail      # => [ [[nil, :A, :B], [nil, :C, :D]], :E, :F, :G]
    #
    # The data structure for an audit gets nasty after a few merges because
    # the lead array gets more and more nested.  Audit provides iterators
    # to help gain access, as well as a printing method to visualize the
    # audit trail:
    #
    #   [c._to_s]
    #   o-[] 1
    #   o-[A] 2
    #   o-[B] 3
    #   | 
    #   | o-[] 10
    #   | o-[C] 11
    #   | o-[D] 12
    #   | | 
    #   `-`-o-[E] "a string value"
    #       o-[F] {"a"=>"hash value"}
    #       o-[G] ["an", "array", "value"]
    #
    # In practice, tasks are recored as sources. Thus source trails can be used  
    # to access task configurations and other information that may be useful 
    # when creating reports or making workflow decisions (ex: raise an 
    # error after looping to a given task too many times). 
    #
    #--
    # TODO:
    # Track nesting level of ams; see if you can hook this into the _to_s process to make 
    # extraction/presentation of audits more managable.
    #
    # Create a FirstLastArray to minimize the audit data collected.  Allow different audit
    # modes:
    # - full        ([] both)
    # - source_only (fl value)
    # - minimal     (fl source and value)
    #
    # Try to work a _to_s that doesn't repeat the same audit twice.  Think about a format
    # like:
    #         | 
    #   ------|-----+
    #         |     | 
    #   ------|-----|-----+ 
    #         |     |     | 
    #         `-----`-----`-o-[j] j5
    #
    class Audit
      autoload(:PP, 'pp')
      
      class << self

        # Creates a new Audit by merging the input audits. The value of the new 
        # Audit will be an array of the _current values of the audits.  The source 
        # will be an AuditMerge whose values are forks of the audits. Non-Audit 
        # sources can be provided; they are initialized to Audits before merging.
        #
        #   a = Audit.new
        #   a._record(:a, 'a')
        # 
        #   b = Audit.new
        #   b._record(:b, 'b')
        # 
        #   c = Audit.merge(a, b, 1)
        #   c._record(:c, 'c')
        # 
        #   c._values        # => [['a','b', 1], 'c']
        #   c._sources       # => [AuditMerge[a, b, Audit.new(1)], :c]
        #
        # If no audits are provided, merge returns a new Audit.  If only one
        # audit is provided, merge returns a fork of that audit.
        def merge(*audits)
          case audits.length
          when 0 then Audit.new
          when 1 then audits[0]._fork
          else
            sources = AuditMerge.new
            audits.each {|a| sources << (a.kind_of?(Audit) ? a._fork : Audit.new(a)) }
            values = audits.collect {|a| a.kind_of?(Audit) ? a._current : a}
          
            Audit.new(values, sources)
          end
        end
      end
      
      # An array of the sources in self
      attr_reader :_sources
      
      # An array of the values in self
      attr_reader :_values
      
      # An arbitrary constant used to identify when no inputs have been
      # provided to Audit.new.  (nil itself cannot be used as nil is a 
      # valid initial value for an audit trail)
      AUDIT_NIL = Object.new
      
      # A new audit takes a value and/or source.  A nil source is typically given
      # for the original value.  
      def initialize(value=AUDIT_NIL, source=nil)
        @_sources = []
        @_values = []
        
        _record(source, value) unless value == AUDIT_NIL
      end

      # Records the next value produced by the source.  When an audit is
      # passed as a value, record will record the current value of the audit.
      # Record will similarly resolve every audit in an array containing audits.
      #
      # Example:
      #
      #    a = Audit.new(1)
      #    b = Audit.new(2)
      #    c = Audit.new(3)
      #
      #    c.record(:a, a) 
      #    c.sources           # => [:a]
      #    c.values            # => [1]
      # 
      #    c.record(:ab, [a,b])
      #    c.sources           # => [:a, :ab]
      #    c.values            # => [1, [1, 2]]
      def _record(source, value)
        _sources << source
        _values << value
        self
      end

      # The original value used to initialize the Audit
      def _original
        _values.first
      end

      # The current (ie last) value recorded in the Audit
      def _current
        _values.last
      end

      # The original source used to initialize the Audit
      def _original_source
        _sources.first
      end
      
      # The current (ie last) source recorded in the Audit
      def _current_source
        _sources.last
      end

      # Searches back and recursively (if the source is an audit) collects all sources 
      # for the current value.
      def _source_trail
        _collect_records {|source, value| source}
      end
      
      # Searches back and recursively (if the source is an audit) collects all values 
      # leading to the current value.
      def _value_trail
        _collect_records {|source, value| value}
      end
      
      def _collect_records(&block) # :yields: source, value
        collection = []
        0.upto(_sources.length-1) do |i|
          collection << collect_records(_sources[i], _values[i], &block)
        end
        collection
      end
      
      def _each_record(merge_level=0, merge_index=0, &block) # :yields: source, value, merge_level, merge_index, index
        0.upto(_sources.length-1) do |i|
          each_record(_sources[i], _values[i], merge_level, merge_index, i, &block)
        end
      end

      # Creates a new Audit by merging self and the input audits, using Audit#merge.
      def _merge(*audits)
        Audit.merge(self, *audits)
      end
      
      # Produces a new Audit with duplicate sources and values, suitable for
      # separate development along a separate path.
      def _fork
        a = Audit.new
        a._sources = _sources.dup
        a._values = _values.dup
        a
      end

      # _forks self and records the next value as [<return from block>, AuditSplit.new(block)] 
      def _split(&block) # :yields: _current
        _fork._record(AuditSplit.new(block), yield(_current))
      end
      
      # _forks self for each member in _current.  Records the next value as
      # [item, AuditExpand.new(<index of item>)].  Raises an error if _current 
      # does not respond to each.
      def _expand
        expanded = []
        _current.each do |value|
          expanded << _fork._record(AuditExpand.new(expanded.length), value)
        end
        expanded
      end
      
      # Returns true if the _sources and _values for self are equal
      # to those of another.
      def ==(another)
        another.kind_of?(Audit) && self._sources == another._sources && self._values == another._values
      end
      
      # A kind of pretty-print for Audits.  See the example in the overview.
      def _to_s
        # TODO -- find a way to avoid repeating groups
        
        group = []
        groups = [group]
        extended_groups = [groups]
        group_merges = []
        extended_group_merges = []
        current_level = nil
        current_index = nil
        
        _each_record do |source, value, merge_level, merge_index, index|  
          source_str, value_str = if block_given?
            yield(source, value)
          else
            [source, value == nil ? '' : PP.singleline_pp(value, '')]
          end
          
          if !group.empty? && (merge_level != current_level || index == 0)
            unless merge_level <= current_level
              groups = [] 
              extended_groups << groups
            end

            group = []
            groups << group 
            
            if merge_level < current_level
              if merge_index == 0
                extended_group_merges << group.object_id
              end
              
              unless index == 0   
                group_merges << group.object_id
              end
            end
          end
      
          group << "o-[#{source_str}] #{value_str}"
          current_level = merge_level
          current_index = merge_index
        end

        lines = []
        group_prefix = ""
        extended_groups.each do |ext_groups|
          indentation = 0

          ext_groups.each_with_index do |ext_group, group_num|
            ext_group.each_with_index do |line, line_num|
              if line_num == 0
                unless lines.empty?
                  lines << group_prefix + "  " * indentation + "| " * (group_num-indentation) 
                end
                
                if group_merges.include?(ext_group.object_id)
                  lines << group_prefix + "  " * indentation + "`-" * (group_num-indentation) + line
                  indentation = group_num
                  
                  if extended_group_merges.include?(ext_group.object_id) 
                    lines.last.gsub!(/\| \s*/) {|match| "`-" + "-" * (match.length - 2)}
                    group_prefix.gsub!(/\| /, " ")
                  end
                  next
                end
              end
              
              lines << group_prefix + "  " * indentation + "| " * (group_num-indentation) + line
            end
          end
          
          group_prefix += "  " * (ext_groups.length-1) + "| "
        end
        
        lines.join("\n") + "\n"
      end
      
      protected  

      attr_writer :_sources, :_values # :nodoc:

      private
      
      # helper method to recursively collect the value trail for a given source
      def collect_records(source, value, &block)
        case source
        when AuditMerge
          collection = []
          0.upto(source.length-1) do |i|
            collection << collect_records(source[i], value[i], &block)
          end
          collection
        when Audit
          source._collect_records(&block)
        else
          yield(source, value)
        end
      end
      
      def each_record(source, value, merge_level, merge_index, index, &block)
        case source
        when AuditMerge
          merge_level += 1 
          0.upto(source.length-1) do |i|
            each_record(source[i], value[i], merge_level, i, index, &block)
          end
        when Audit
          source._each_record(merge_level, merge_index, &block)
        else
          yield(source, value, merge_level, merge_index, index)
        end
      end
    end
  end
end
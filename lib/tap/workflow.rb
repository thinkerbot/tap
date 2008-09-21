module Tap
  
  # Workflow is a specialized type of Task allowing the encapsulation and reuse of  
  # workflow logic.  Workflows are still under construction.
  #
  # === Workflow Definition
  #
  # During initialization, Workflow executes the workflow method (by default the
  # block provided to Workflow.new) to define the workflow logic.  This method
  # defines one or more entry_points and zero or more exit points, as well as 
  # the internal logic for the workflow.
  #
  #   Workflow.new do |w|
  #     factor = w.config[:factor] || 1
  #
  #     t1 = Task.new {|task, input| input += 1 }
  #     t2 = Task.new {|task, input| input += 10 }
  #     t3 = Task.new {|task, input| input *= factor }
  #   
  #     w.app.sequence(t1, t2, t3)
  #     w.entry_point = t1
  #     w.exit_point = t3
  #   end
  #
  # Or equivalently:
  #
  #   class SimpleSequence < Workflow
  #     config :factor, 1
  #
  #     def workflow
  #       t1 = Task.new {|task, input| input += 5 }
  #       t2 = Task.new {|task, input| input += 3 }
  #       t3 = Task.new {|task, input| input *= factor }
  #   
  #       app.sequence(t1, t2, t3)
  #       self.entry_point = t1
  #       self.exit_point = t3
  #     end
  #   end
  #
  # To facilitate the specification of entry and exit points, workflow
  # can accomodate either single-task assignments or a collection.  By
  # default both are hashes, but they can be reassigned:
  # 
  #   Workflow.new do |w| 
  #     w.entry_point.class                           # => Hash
  #     w.exit_point.class                            # => Hash
  #     w.entry_point[:main] = Task.new
  #   end
  #
  #   Workflow.new {|w| w.entry_point = Task.new }
  #   Workflow.new {|w| w.entry_point = [Task.new, Task.new] }
  #
  # Access to the group of entry/exit points is standardized to an
  # array via the entry_points and exit_points methods.
  #
  # === Workflow Behavior
  #
  # The entry points act as an enque batch; when the workflow is enqued, the 
  # entry points are enqued.  The exit points act as an on_complete batch; their
  # on_complete blocks are set for workflow.on_complete.  
  #
  #   w = SimpleSequence.new
  #   w.enq(0)
  #   app.run
  #   app.results(w.exit_points)                      # => [8]
  #
  # The batching of entry and exit points is distinct from workflow.batch itself. 
  # Workflows can be batched like Tasks, such that all entry points from all 
  # workflows in a batch are enqued at once. 
  #
  #   w1 = SimpleSequence.new nil, :factor => 1
  #   w2 = w1.initialize_batch_obj nil, :factor => -1
  #
  #   w1.enq(0)
  #   app.run
  #   app.results(w1.exit_points, w2.exit_points))    # => [8, -8]
  #
  class Workflow < Task


    # The entry point for self.
    attr_accessor :entry_point
    
    # The exit point for self.
    attr_accessor :exit_point

    # Creates a new Task with the specified attributes.
    def initialize(config={}, name=nil, app=App.instance, &task_block)
      super
      initialize_workflow
    end
    
    # Initializes a new batch object, running workflow to set the 
    # instance-specific entry/exit points.  Raises an error if
    # no entry points are defined.
    def initialize_copy(orig)
      super
      initialize_workflow
    end
    
    def initialize_workflow
      @entry_point = {}
      @exit_point = {}
      workflow
    end
    
    # Returns an array of entry points, determined from entry_point.
    def entry_points
      case @entry_point
      when Hash then @entry_point.values
      when Support::Executable then [@entry_point]
      when Array then @entry_point
      when nil then []
      else raise "unable to determine entry points from entry_point: #{@entry_point}"
      end
    end
    
    # Returns an array of exit points, determined from exit_point.
    def exit_points
      case @exit_point
      when Hash then @exit_point.values
      when Support::Executable then [@exit_point]
      when Array then @exit_point
      when nil then []
      else raise "unable to determine exit points from exit_point: #{@exit_point}"
      end
    end
    
    # Enqueues all entry points for self and self.batch to app 
    # with the inputs. The number of inputs provided should match 
    # the number of inputs required by all the entry points;
    # if the entry points have different input requirements, they
    # have to be enqued separately.
    def unbatched_enq(*inputs)
      entry_points.each do |task|
        app.enq(task, *inputs)
      end
    end
  
    # Sets the on_complete_block for all exit points for self and 
    # self.batch. Use unbatched_on_complete to set the on_complete_block
    # for just self.exit_points.
    def unbatched_on_complete(override=false, &block)
      exit_points.each do |task|
        task.on_complete(override, &block)
      end
      self
    end
   
    # The workflow definition method.  By default workflow
    # simply calls the task_block.  In subclasses, workflow
    # should be overridden to provide the workflow definition.
    def workflow
      task_block.call(self) if task_block
    end
    
    def process(*inputs)
      enq(*inputs)
    end
  end
end
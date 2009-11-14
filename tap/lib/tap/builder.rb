module Tap
  
  # Builds and sets an application object.  The build spec is a hash
  # defining these fields:
  #
  #   var     # a variable to identify the object
  #   class   # the class name or identifier, as a string
  #   spec    # an array or hash for initialization
  #
  # Build resolves the class string to a constant using env[class], if env
  # is specified, or by directly translating the string into a constant name
  # if env is nil.  The class is then initialized using the spec using one
  # of these methods (in both cases self is the current app):
  #
  #   klass.parse!(spec, self)    # spec is an Array
  #   klass.build(spec, self)     # spec is a Hash
  #
  # The parse! or build method should return the instance and an array of
  # any leftover arguments.  The instance is set to var in objects, if
  # specifed, and then build returns the instance and leftover arguments in
  # an array like [instance, args].
  class Builder
    attr_reader :app
    
    def initialize(app)
      @app = app
    end
    
    def call(argh)
      argh.kind_of?(Array) ? parse!(argh) : build(argh)
    end
    
    def build(spec)
      vars = spec['var'] || []
      clas = spec['class']
      spec = spec['spec'] || spec
      obj = app.resolve(clas).build(spec, app)

      vars = [vars] unless vars.kind_of?(Array)
      vars.each {|var| app.set(var, obj) }

      obj
    end
    
    def parse!(argv)
      var, clas, *args = argv
      obj = app.resolve(clas).parse!(args, app) # obj, args =
      app.set(var, obj) if var

      [obj, args]
    end
  end
end
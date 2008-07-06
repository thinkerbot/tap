class SampleFile < Tap::FileTask
  # use config to set task configurations
  # configs have accessors by default
  
  config :key, 'value'           # a sample config
  
  # process defines what the task does; use the
  # same number of inputs to enque the task
  # as specified here
  def process(filepath)

    # infer an output filepath relative to the :data directory, 
    # (this is convenient for testing) while changing the 
    # basename of filepath to 'yml'.  See FileTask#filepath 
    # for filepaths based on the task name.
    target = app.filepath(:data, basename(filepath, '.yml') )

    # prepare ensures the parent directory for 
    # output exists, and that output does not; 
    # any existing file is backed up and reverts
    # in the event of an error
    prepare(target) 
    
    # now perform the task...
    array = File.read(filepath).split(/\r?\n/)
    File.open(target, "wb") do |file|
      file << array.to_yaml
    end
    
    target
  end
  
end
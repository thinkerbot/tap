require 'active_support'
require 'fileutils'
require 'test/unit'

class DependenciesCheck < Test::Unit::TestCase
  
  def teardown
    FileUtils.rm_r(dep_dir)
  end
  
  def dep_dir
    File.join( File.dirname(__FILE__), "dependencies" )
  end
  
  #
  # make files
  #
  
  def filepath(class_name)
    File.join(dep_dir, class_name.underscore + ".rb")
  end
  
  def make_file(class_name, content)
    path = filepath(class_name)
    FileUtils.mkdir(File.dirname(path)) unless File.exists?(File.dirname(path))
    File.open(path, "w") do |file|
      file << content
    end
    class_name.underscore
  end
  
  def make_module_file(class_name)
    make_file class_name, %Q{
module #{class_name.camelize}
end}
  end
  
  def make_unloadable_file(class_name)
    make_file class_name, %Q{
module #{class_name.camelize}
  unloadable
end}
  end
  
  #
  # dependencies check
  #
  
  def test_dependencies
    pre_load = make_module_file "PreLoad"
    pre_load_unloadable = make_unloadable_file "PreLoadUnloadable"
    pre_loader = make_file("PreLoader", "require 'pre_load_required'\nrequire 'pre_load_required_unloadable'")
    pre_load_required = make_module_file "PreLoadRequired"
    pre_load_required_unloadable = make_unloadable_file "PreLoadRequiredUnloadable"
    pre_load_consts = ["PreLoad", "PreLoadUnloadable", "PreLoadRequired", "PreLoadRequiredUnloadable"]
    
    post_load = make_module_file "PostLoad"
    post_load_unloadable = make_unloadable_file "PostLoadUnloadable"
    post_loader = make_file("PostLoader", "require 'post_load_required'\nrequire 'post_load_required_unloadable'")
    post_load_required = make_module_file "PostLoadRequired"
    post_load_required_unloadable = make_unloadable_file "PostLoadRequiredUnloadable"
    post_load_consts = ["PostLoad", "PostLoadUnloadable", "PostLoadRequired", "PostLoadRequiredUnloadable"]
    
    assert_equal 10, Dir.glob( File.join( dep_dir, "*") ).length
    
    # can't load if not on load path
    assert_raise(MissingSourceFile) do
      require pre_load
    end
    
    $:.unshift dep_dir
    assert_nothing_raised do
      require pre_load
      require pre_load_unloadable
      require pre_loader
    end
    
    pre_load_consts.each {|const| assert Object.const_defined?(const)}
    post_load_consts.each {|const| assert !Object.const_defined?(const)}

    # now set Dependencies to load from dep_dir
    Dependencies.load_paths << dep_dir
    
    # PostLoad constants will be autoloaded as missing constants by Dependencies
    assert PostLoad
    assert PostLoadUnloadable
    assert PostLoadRequired
    assert PostLoadRequiredUnloadable
    
    pre_load_consts.each {|const| assert Object.const_defined?(const)}
    post_load_consts.each {|const| assert Object.const_defined?(const)}
    
    # post load modules are cleared, and pre-unloadable modules.
    # other modules are not cleared 
    Dependencies.clear
    
    ["PreLoad", "PreLoadRequired"].each {|const| assert Object.const_defined?(const)}
    ["PreLoadUnloadable", "PreLoadRequiredUnloadable"].each {|const| assert !Object.const_defined?(const)}
    post_load_consts.each {|const| assert !Object.const_defined?(const)}

    # calling the missing modules reloads them
    assert PreLoadUnloadable
    assert PreLoadRequiredUnloadable
    
    assert PostLoad
    assert PostLoadUnloadable
    assert PostLoadRequired
    assert PostLoadRequiredUnloadable
    
    pre_load_consts.each {|const| assert Object.const_defined?(const)}
    post_load_consts.each {|const| assert Object.const_defined?(const)}
    
    # As before, post load modules should be cleared, and pre-unloadable modules
    Dependencies.clear
    
    ["PreLoad", "PreLoadRequired"].each {|const| assert Object.const_defined?(const)}
    ["PreLoadUnloadable", "PreLoadRequiredUnloadable"].each {|const| assert !Object.const_defined?(const)}
    post_load_consts.each {|const| assert !Object.const_defined?(const)}
    
    # requiring files will NOT restore pre-loads by themselves... 
    # but it will restore post load requires, because they haven't 
    # been required yet
    assert_nothing_raised do
      require pre_load
      require pre_load_unloadable
      require pre_loader
      
      require post_load
      require post_load_unloadable
      require post_loader
    end
    
    ["PreLoad", "PreLoadRequired"].each {|const| assert Object.const_defined?(const)}
    ["PreLoadUnloadable", "PreLoadRequiredUnloadable"].each {|const| assert !Object.const_defined?(const)}
    post_load_consts.each {|const| assert Object.const_defined?(const)}
    
    # Now, ONLY unloadable modules will be cleared -- the others were loaded
    # using require, and NOT Dependencies autoloading
    Dependencies.clear
    
    ["PreLoad", "PreLoadRequired"].each {|const| assert Object.const_defined?(const)}
    ["PreLoadUnloadable", "PreLoadRequiredUnloadable"].each {|const| assert !Object.const_defined?(const)}
    ["PostLoad", "PostLoadRequired"].each {|const| assert Object.const_defined?(const)}
    ["PostLoadUnloadable", "PostLoadRequiredUnloadable"].each {|const| assert !Object.const_defined?(const)}
    
    # Now, requiring files will NOT restore any modules because 
    # the files have already been required
    assert_nothing_raised do
      require pre_load
      require pre_load_unloadable
      require pre_loader
      
      require post_load
      require post_load_unloadable
      require post_loader
    end
    
    ["PreLoad", "PreLoadRequired"].each {|const| assert Object.const_defined?(const)}
    ["PreLoadUnloadable", "PreLoadRequiredUnloadable"].each {|const| assert !Object.const_defined?(const)}
    ["PostLoad", "PostLoadRequired"].each {|const| assert Object.const_defined?(const)}
    ["PostLoadUnloadable", "PostLoadRequiredUnloadable"].each {|const| assert !Object.const_defined?(const)}
    
    # but again... calling the missing modules reloads them, so even
    # though the require doesn't work, you shold be good because you
    # won't be accessing the module without calling it.  (right?)
    assert PreLoadUnloadable
    assert PreLoadRequiredUnloadable
    assert PostLoadUnloadable
    assert PostLoadRequiredUnloadable
    
    pre_load_consts.each {|const| assert Object.const_defined?(const)}
    post_load_consts.each {|const| assert Object.const_defined?(const)}
  end
  
end
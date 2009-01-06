require 'tap/support/shell_utils'
autoload(:FileUtils, "fileutils")

module Tap
  
  # FileTask is a base class for tasks that work with a file system.  FileTask
  # tracks changes it makes so they may be rolled back to their original state.
  # Rollback automatically occurs on an execute error.
  #
  #   File.open("file.txt", "w") {|file| file << "original content"}
  #  
  #   t = FileTask.intern do |task, raise_error|
  #     task.mkdir_p("some/dir")              # marked for rollback
  #     task.prepare("file.txt") do |file|    # marked for rollback
  #       file << "new content"
  #     end
  #
  #     # raise an error to start rollback
  #     raise "error!" if raise_error
  #   end
  #
  #   begin
  #     t.execute(true)
  #   rescue
  #     $!.message                            # => "error!"
  #     File.exists?("some/dir")              # => false
  #     File.read("file.txt")                 # => "original content"
  #   end
  #
  #   t.execute(false)
  #   File.exists?("some/dir")                # => true
  #   File.read("file.txt")                   # => "new content"
  #
  class FileTask < Task
    include Tap::Support::ShellUtils
    
    # The backup directory
    config_attr :backup_dir, 'backup'            # the backup directory
    
    # A flag indicating whether or track changes
    # for rollback on execution error
    config :rollback_on_error, true, &c.switch   # rollback changes on error
    
    def initialize(config={}, name=nil, app=App.instance)
      super
      @actions = []
    end
    
    # Initializes a copy that will rollback independent of self.
    def initialize_copy(orig)
      super
      @actions = []
    end
    
    # Returns the path, exchanging the extension with extname.  
    # A false or nil extname removes the extension, while true 
    # preserves the existing extension (and effectively does
    # nothing).
    #
    #   t = FileTask.new
    #   t.basepath('path/to/file.txt')           # => 'path/to/file'
    #   t.basepath('path/to/file.txt', '.html')  # => 'path/to/file.html'
    #
    #   t.basepath('path/to/file.txt', false)    # => 'path/to/file'
    #   t.basepath('path/to/file.txt', true)     # => 'path/to/file.txt'
    #
    # Compare to basename.
    def basepath(path, extname=false)
      case extname
      when false, nil then path.chomp(File.extname(path))
      when true then path
      else Root.exchange(path, extname)
      end
    end
    
    # Returns the basename of path, exchanging the extension 
    # with extname.  A false or nil extname removes the
    # extension, while true preserves the existing extension.
    #
    #   t = FileTask.new
    #   t.basename('path/to/file.txt')           # => 'file.txt'
    #   t.basename('path/to/file.txt', '.html')  # => 'file.html'
    #
    #   t.basename('path/to/file.txt', false)    # => 'file'
    #   t.basename('path/to/file.txt', true)     # => 'file.txt'
    #
    # Compare to basepath.
    def basename(path, extname=true)
      basepath(File.basename(path), extname)
    end
    
    # Constructs a filepath using the dir, name, and the specified paths.
    #
    #   t = FileTask.new 
    #   t.app[:data, true] = "/data" 
    #   t.name                              # => "tap/file_task"
    #   t.filepath(:data, "result.txt")     # => "/data/tap/file_task/result.txt"
    #
    def filepath(dir, *paths) 
      app.filepath(dir, name, *paths)
    end
    
    # Makes a backup filepath relative to backup_dir by using name, the
    # basename of filepath, and an index. 
    #
    #   t = FileTask.new({:backup_dir => "/backup"}, "name")
    #   t.backup_filepath("path/to/file.txt", time)     # => "/backup/name/file.0.txt"
    #   
    def backup_filepath(path)
      extname = File.extname(path)
      backup_path = filepath(backup_dir, File.basename(path).chomp(extname))
      next_indexed_path(backup_path, 0, extname)
    end

    # Returns true if all of the targets are up to date relative to all of the
    # listed sources. Single values or arrays can be provided for both targets
    # and sources.
    #
    # Returns false (ie 'not up to date') if app.force is true.
    #
    #--
    # TODO: add check vs date reference (ex config_file date)
    def uptodate?(targets, sources=[])
      if app.force
        log_basename(:force, *targets)
        false
      else
        targets = [targets] unless targets.kind_of?(Array)
        sources = [sources] unless sources.kind_of?(Array)
        
        targets.each do |target|
          return false unless FileUtils.uptodate?(target, sources)
        end 
        true
      end
    end
    
    # Makes a backup of path to backup_filepath(path) and returns the backup path.
    # If backup_using_copy is true, the backup is a copy of path, otherwise the
    # file or directory at path is moved to the backup path.  Raises an error if
    # the backup path already exists.
    #
    # Backups are restored on rollback.
    #
    #   file = "file.txt"
    #   File.open(file, "w") {|f| f << "file content"}
    #
    #   t = FileTask.new
    #   backup_file = t.backup(file)
    #       
    #   File.exists?(file)                       # => false
    #   File.exists?(backup_file)                # => true
    #   File.read(backup_file)                   # => "file content"
    #
    #   File.open(file, "w") {|f| f << "new content"}
    #   t.rollback
    #
    #   File.exists?(file)                       # => true
    #   File.exists?(backup_file   )             # => false
    #   File.read(file)                          # => "file content"
    #
    def backup(path, backup_using_copy=false)
      return nil unless File.exists?(path)
        
      source = File.expand_path(path)
      target = backup_filepath(source)
      raise "backup already exists: #{target}" if File.exists?(target)
      
      mkdir_p File.dirname(target)
      
      log :backup, "#{source} to #{target}", Logger::DEBUG
      if backup_using_copy
        FileUtils.cp(source, target)
      else
        FileUtils.mv(source, target)
      end
      
      actions << [:backup, source, target]
      target
    end
    
    # Creates a directory and all its parent directories. Directories created
    # by mkdir_p removed on rollback.
    def mkdir_p(dir)
      dir = File.expand_path(dir)
        
      dirs = []
      while !File.exists?(dir)
        dirs.unshift(dir)
        dir = File.dirname(dir)
      end
        
      dirs.each {|d| mkdir(d) }
    end
    
    # Creates a directory. Directories created by mkdir removed on rollback.
    def mkdir(dir)
      dir = File.expand_path(dir)
      
      unless File.exists?(dir)
        log :mkdir, dir, Logger::DEBUG
        FileUtils.mkdir(dir)
        actions << [:make, dir]
      end
    end
    
    # Prepares the path by backing up any existing file and ensuring that
    # the parent directory for path exists.  If a block is given, a file
    # is opened and yielded to it (as in File.open).  Prepared paths are
    # removed and the backups restored on rollback.
    #
    # Returns the expanded path.
    def prepare(path, backup_using_copy=false) 
      raise "not a file: #{path}" if File.directory?(path)
      path = File.expand_path(path)

      if File.exists?(path)
       # backup or remove existing files
        backup(path, backup_using_copy)
      else
        # ensure the parent directory exists
        # for non-existant files 
        mkdir_p File.dirname(path)
      end
      log :prepare, path, Logger::DEBUG
      actions << [:make, path]
      
      if block_given?
        File.open(path, "w") {|file| yield(file) }
      end
      
      path
    end
    
    # Removes a file.  If a directory is provided, it's contents are removed
    # recursively.  Files and directories removed by rm_r are restored
    # upon an execution error.
    def rm_r(path) 
      path = File.expand_path(path)
      
      backup(path, false)
      log :rm_r, path, Logger::DEBUG
    end
    
    # Removes an empty directory.  Directories removed by rmdir are restored
    # upon an execution error.
    def rmdir(dir)
      dir = File.expand_path(dir)
      
      unless Root.empty?(dir)
        raise "not an empty directory: #{dir}"
      end
      
      backup(dir, false)
      log :rmdir, dir, Logger::DEBUG
    end
    
    # Removes a file.  Directories cannot be removed by this method.
    # Files removed by rm are restored upon an execution error.
    def rm(path) 
      path = File.expand_path(path)
      
      unless File.file?(path)
        raise "not a file: #{path}"
      end
      
      backup(path, false)
      log :rm, path, Logger::DEBUG
    end
    
    # Copies source to target.  Files and directories copied by cp are
    # restored upon an execution error.
    def cp(source, target)
      target = File.join(target, File.basename(source)) if File.directory?(target)
      prepare(target)
      
      log :cp, "#{source} to #{target}", Logger::DEBUG
      FileUtils.cp(source, target)
    end
    
    # Copies source to target.  If source is a directory, the contents
    # are copied recursively.  If target is a directory, copies source
    # to target/source.  Files and directories copied by cp are restored
    # upon an execution error.
    def cp_r(source, target)
      target = File.join(target, File.basename(source)) if File.directory?(target)
      prepare(target)
      
      log :cp_r, "#{source} to #{target}", Logger::DEBUG
      FileUtils.cp_r(source, target)
    end
    
    # Moves source to target.  Files and directories moved by mv are
    # restored upon an execution error.
    def mv(source, target, backup_source=true)
      backup(source, true) if backup_source
      prepare(target)
      
      log :mv, "#{source} to #{target}", Logger::DEBUG
      FileUtils.mv(source, target)
    end
    
    # Rolls back any actions capable of being rolled back.
    #
    # Rollback is forceful.  For instance if you make a folder using
    # mkdir, rollback will remove the folder and all files within it
    # even if they were not added by self.
    def rollback
      while !actions.empty?
        action, source, target = actions.pop

        case action
        when :make
          log :rollback, "#{source}", Logger::DEBUG
          FileUtils.rm_r(source)
        when :backup
          log :rollback, "#{target} to #{source}", Logger::DEBUG
          dir = File.dirname(source)
          FileUtils.mkdir_p(dir) unless File.exists?(dir)
          FileUtils.mv(target, source, :force => true)
        else
          raise "unknown action: #{[action, source, target].inspect}"
        end
      end
    end
    
    # Removes backup files. Cleanup cannot be rolled back and prevents
    # rollback of actions up to when cleanup is called.  If cleanup_dirs
    # is true, empty directories containing the backup files will be
    # removed.
    def cleanup(cleanup_dirs=true)
      actions.each do |action, source, target|
        if action == :backup
          log :cleanup, target, Logger::DEBUG
          FileUtils.rm_r(target) if File.exists?(target)
          cleanup_dir(File.dirname(target)) if cleanup_dirs
        end
      end
      actions.clear
    end
    
    # Removes the directory if empty, and all empty parent directories. This
    # method cannot be rolled back.
    def cleanup_dir(dir)
      while Root.empty?(dir)
        log :rmdir, dir, Logger::DEBUG
        FileUtils.rmdir(dir)
        dir = File.dirname(dir)
      end
    end
    
    # Logs the given action, with the basenames of the input paths.  
    def log_basename(action, paths, level=Logger::INFO)
      msg = [paths].flatten.collect {|path| File.basename(path) }.join(',')
      log(action, msg, level)
    end
    
    protected
    
    # An array tracking actions (backup, rm, mv, etc) performed by self,
    # allowing rollback on an execution error.  Not intended to be
    # modified manually.
    attr_reader :actions
    
    # Clears actions so that a failure will not affect previous executions
    def before_execute
      actions.clear
    end
    
    # Removes made files/dirs and restores backed-up files upon 
    # an execute error.
    def on_execute_error(original_error)
      rollback if rollback_on_error
      raise original_error
    end
    
    private 

    # utility method for backup_filepath; increments index until the
    # path base.indexext does not exist.
    def next_indexed_path(base, index, ext) # :nodoc:
      path = sprintf('%s.%d%s', base, index, ext)
      File.exists?(path) ? next_indexed_path(base, index + 1, ext) : path
    end
  end
end

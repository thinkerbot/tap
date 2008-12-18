require 'tap/support/shell_utils'
autoload(:FileUtils, "fileutils")

module Tap
  
  # FileTask is a base class for tasks that work with a file system.  FileTask
  # tracks changes it makes using added_files, and the backed_up_files hash.
  # On an execute error, changes made by a FileTask are rolled back to their
  # original state.
  #
  #   # this file will be backed up and restored
  #   File.open("file.txt", "w") {|f| f << "original content"}
  #  
  #   t = FileTask.intern do |task|
  #     task.mkdir_p("some/dir")                       # marked for rollback
  #     task.prepare("file.txt", "path/to/file.txt")   # marked for rollback
  #
  #     File.open("file.txt", "w") {|f| f << "new content"}
  #     File.touch("path/to/file.txt")
  #
  #     # raise an error to start rollback
  #     raise "error!"
  #   end
  #
  #   begin
  #     File.exists?("some/dir")              # => false
  #     File.exists?("path/to/file.txt")      # => false
  #     t.execute(nil)
  #   rescue
  #     $!.message                            # => "error!"
  #     File.exists?("some/dir")              # => false
  #     File.exists?("path/to/file.txt")      # => false
  #     File.read("file.txt")                 # => "original content"
  #   end
  #
  #--
  # ==== Backup/Restore
  # The idea is that the originals are backed up once, and added files/dirs
  # are recorded.  This is the minimal information to restore the incoming
  # directory structure... it is meaningless to try to incrementally roll
  # back, so tracking of individual actions is unnecessary.
  class FileTask < Task
    include Tap::Support::ShellUtils
    
    # The backup directory, defaults to the class backup_dir
    config_attr :backup_dir, 'backup'            # the backup directory
    
    # A timestamp format used to mark backup files, defaults
    # to the class backup_timestamp
    config :timestamp, "%Y%m%d_%H%M%S"           # the backup timestamp format
    
    # A flag indicating whether or not to rollback changes on
    # error, defaults to the class rollback_on_error
    config :rollback_on_error, true, &c.switch   # rollback changes on error
    
    def initialize(config={}, name=nil, app=App.instance)
      super
      @actions = []
    end
    
    # Initializes a copy with it's own backed_up_files and added_files.
    def initialize_copy(orig)
      super
      @actions
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
    
    # Makes a backup filepath relative to backup_dir by using self.name, the 
    # basename of filepath plus a timestamp and index. 
    #
    #   t = FileTask.new({:timestamp => "%Y%m%d"}, 'name')
    #   t.app['backup', true] = "/backup"
    #   time = Time.utc(2008,8,8)
    #
    #   t.backup_filepath("path/to/file.txt", time)     # => "/backup/name/file_20080808_0.txt"
    #   
    def backup_filepath(path, time=Time.now)
      extname = File.extname(path)
      backup_path = filepath(backup_dir, "#{File.basename(path).chomp(extname)}_#{time.strftime(timestamp)}")
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
    # the backup file already exists.
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
      raise "backup file already exists: #{target}" if File.exists?(target)
      
      mkdir_p File.dirname(target)
      
      log :backup, "#{source} to #{target}", Logger::DEBUG
      if backup_using_copy
        FileUtils.cp(source, target)
      else
        FileUtils.mv(source, target)
      end
      
      actions << [:mv, source, target]
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
        
      dirs.each {|dir| mkdir(dir) }
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
    
    # Prepares the input file by backing up any existing file and ensuring that
    # the parent directory for the file exists.  If a block is given, the file
    # is opened and yielded as in File.open.  Prepared files are removed and
    # the backups restored on rollback.
    #
    # Returns the prepared file.
    #
    #   File.open("file.txt", "w") {|f| f << "original content"}
    #
    #   t = FileTask.new do |task, inputs|   
    #     task.prepare("file.txt") {|f| f << "new content"}
    #     File.read('file.txt')                 # => "new content"
    #
    #     raise "error!"
    #   end
    #
    #   begin
    #     t.execute(nil)
    #   rescue
    #     $!.message                            # => "error!"
    #     File.exists?("file.txt")              # => true
    #     File.read("file.txt")                 # => "original content"
    #     File.exists?("path")                  # => false
    #   end
    #
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
      actions << [:make, path]
      
      if block_given?
        File.open(path, "w") {|file| yield(file) }
      end
      
      path
    end
    
    # Removes one or more files.  If a directory is provided, it's contents are
    # removed recursively.  Files and directories removed by rm_r are restored
    # upon an execution error.
    def rm_r(path) 
      path = File.expand_path(path)
      
      backup(path, false)
      log :rm_r, path, Logger::DEBUG
    end
    
    # Removes one or more directories.  Directories removed by rmdir
    # are restored upon an execution error.
    def rmdir(dir)
      dir = File.expand_path(dir)
      
      unless Root.empty?(dir)
        raise "not an empty directory: #{dir}"
      end
      
      backup(dir, false)
      log :rmdir, dir, Logger::DEBUG
    end
    
    # Removes one or more files.  Directories cannot be removed by this method.
    # Files removed by rm are restored upon an execution error.
    def rm(path) 
      path = File.expand_path(path)
      
      unless File.file?(path)
        raise "not a file: #{path}"
      end
      
      backup(path, false)
      log :rm, path, Logger::DEBUG
    end
    
    def cp(source, target)
      prepare(target)
      
      log :cp, "#{source} to #{target}", Logger::DEBUG
      FileUtils.cp(source, target)
    end
    
    def mv(source, target, backup_source=true)
      backup(source, true) if backup_source
      prepare(target)
      
      log :mv, "#{source} to #{target}", Logger::DEBUG
      FileUtils.mv(source, target)
    end
    
    # Rolls back changes by restoring backed_up_files and removing added_files.
    # Rollback is automatically performed on an execute error if 
    # rollback_on_error == true, but is provided as a separate method for
    # flexibility when needed.
    def rollback(n=actions.length)
      # begin
        while n > 0
          action, source, target = actions.pop

          case action
          when :make
            log :rm_r, "#{source}", Logger::DEBUG
            FileUtils.rm_r(source)
          when :mv
            log :mv, "#{target} to #{source}", Logger::DEBUG
            dir = File.dirname(source)
            FileUtils.mkdir_p(dir) unless File.exists?(dir)
            FileUtils.mv(target, source, :force => true)
          when nil
            raise "nothing to rollback"
          else
            raise "unknown action: #{[action, source, target].inspect}"
          end
          
          n -= 1
        end
      # rescue
      #   print error
      #   dump to a file for manual restore
      # end
    end
    
    def cleanup
      actions.each do |action, source, target|
        FileUtils.rm_r(target) if target
      end
      actions.clear
    end
    
    # Logs the given action, with the basenames of the input paths.  
    def log_basename(action, paths, level=Logger::INFO)
      msg = [paths].flatten.collect {|path| File.basename(path) }.join(',')
      log(action, msg, level)
    end
    
    protected
    
    # A hash of backup (source, target) pairs, such that the path to the
    # original file is the source and the backed-up file is the target.  
    # All filepaths in backed_up_files should be expanded.
    attr_reader :actions
    
    # Clears added_files and backed_up_files so that  
    # a failure will not affect previous executions
    def before_execute
      actions.clear
    end
    
    # Removes made files/dirs and restores backed-up files upon 
    # an execute error.  Collects any errors raised along the way
    # and raises them in a Tap::Support::RunError.
    def on_execute_error(original_error)
      rollback if rollback_on_error
      raise original_error
    end
    
    # utility method for backup_filepath; increments index until the
    # path base.indexext does not exist.
    def next_indexed_path(base, index, ext) # :nodoc:
      path = sprintf('%s_%d%s', base, index, ext)
      File.exists?(path) ? next_indexed_path(base, index + 1, ext) : path
    end
  end
end

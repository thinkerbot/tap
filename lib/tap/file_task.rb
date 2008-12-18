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
    
    # A hash of backup (source, target) pairs, such that the path to the
    # original file is the source and the backed-up file is the target.  
    # All filepaths in backed_up_files should be expanded.
    attr_reader :backed_up_files
    
    # An array of files/directories added during execution.  
    attr_reader :added_files
 
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
      @backed_up_files = {}
      @added_files = []
    end
    
    # Initializes a copy with it's own backed_up_files and added_files.
    def initialize_copy(orig)
      super
      @backed_up_files = {}
      @added_files = []
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
    # basename of filepath plus a timestamp. 
    #
    #   t = FileTask.new({:timestamp => "%Y%m%d"}, 'name')
    #   t.app['backup', true] = "/backup"
    #   time = Time.utc(2008,8,8)
    #
    #   t.backup_filepath("path/to/file.txt", time)     # => "/backup/name/file_20080808.txt"
    #   
    def backup_filepath(filepath, time=Time.now)
      extname = File.extname(filepath)
      backup_path = "#{File.basename(filepath).chomp(extname)}_#{time.strftime(timestamp)}#{extname}"
      filepath(backup_dir, backup_path)
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
    
    # Makes a backup of each file in list to backup_filepath(file) and registers 
    # the files so that they can be restored using restore.  If backup_using_copy 
    # is true, the files will be copied to backup_filepath, otherwise the file is 
    # moved to backup_filepath.  Raises an error if the file is already listed
    # in backed_up_files.
    #
    # Returns a list of the backup_filepaths.
    #
    #   file = "file.txt"
    #   File.open(file, "w") {|f| f << "file content"}
    #
    #   t = FileTask.new
    #   t.backup(file)
    #   backed_up_file = t.backed_up_files[file]   
    #       
    #   File.exists?(file)                       # => false
    #   File.exists?(backed_up_file)             # => true
    #   File.read(backed_up_file)                # => "file content"
    #
    #   File.open(file, "w") {|f| f << "new content"}
    #   t.restore(file, true)
    #
    #   File.exists?(file)                       # => true
    #   File.exists?(backed_up_file)             # => false
    #   File.read(file)                          # => "file content"
    #
    #--
    # note backups are restored on error
    def backup(list, backup_using_copy=false)
      fu_list(list).each do |path|
        next unless File.exists?(path)
        
        source = File.expand_path(path)
        if backed_up_files.include?(source)
          raise "already backed up: #{source}" 
        end
        
        target = backup_filepath(source)
        if File.exists?(target)
          raise "backup file already exists: #{target}"
        end
        mkdir_p File.dirname(target)
        
        log :backup, "#{source} to #{target}", Logger::DEBUG
        if backup_using_copy
          FileUtils.cp(source, target)
        else
          FileUtils.mv(source, target)
        end

        # track the target for restores
        backed_up_files[source] = target
      end
    end
    
    # Restores each file in the input list using the backup file from
    # backed_up_files.  The backup directory is removed if it is empty.
    #  
    # Returns a list of the restored files.
    #
    #--
    # note restore cannot be rolled back... it is a rollback
    def restore(list, remove_backup=false)
      fu_list(list).each do |path|
        source = File.expand_path(path)
        next unless target = backed_up_files[source]
      
        mkdir_p File.dirname(source)
        
        log :restore, "#{target} to #{source}", Logger::DEBUG
        if remove_backup
          FileUtils.mv(target, source, :force => true)
          backed_up_files.delete(source)
          cleanup_dir File.dirname(target)
        else
          FileUtils.cp(target, source)
        end
      end
    end
    
    # Creates a directory and all its parent directories.  More than one
    # directory may be provided as a list.  Directories created by mkdir_p
    # are removed upon an execution error.
    def mkdir_p(list)
      fu_list(list).each do |dir|
        dir = File.expand_path(dir)
        
        dirs = []
        while !File.exists?(dir)
          dirs.unshift(dir)
          dir = File.dirname(dir)
        end
        
        mkdir(dirs)
      end
    end
    
    # Creates one or more directories.  Directories created by mkdir
    # are removed upon an execution error.
    def mkdir(list)
      fu_list(list).collect do |dir|
        File.expand_path(dir)
      end.sort.each do |dir|
        unless File.exists?(dir)
          log :mkdir, dir, Logger::DEBUG
          FileUtils.mkdir(dir)
          added_files << dir
        end
      end
    end
    
    # Prepares the input list of files ensuring that the parent directory for
    # the file exists.  Files prepared in this way will be rolled back upon an 
    # execution error.
    #
    # Returns the prepared files.
    #
    #   File.open("file.txt", "w") {|f| f << "original content"}
    #
    #   t = FileTask.new do |task, inputs|
    #     File.exists?("path")                  # => false
    #
    #     # backup... make parent dirs... prepare for restore     
    #     task.prepare(["file.txt", "path/to/file.txt"])
    #
    #     File.open("file.txt", "w") {|f| f << "new content"}
    #     File.touch("path/to/file.txt")
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
    def prepare(list, backup_using_copy=false) 
      list = fu_list(list).collect do |path|
        raise "not a file: #{path}" if File.directory?(path)
        File.expand_path(path)
      end
      
      existing_files, non_existant_files = list.partition do |path|
        File.exists?(path)
      end
      
      # backup or remove existing files
      existing_files.each do |path|
        if backed_up_files.include?(path)
          FileUtils.rm(path)
        else
          backup(path, backup_using_copy)
        end
      end
      
      # ensure the parent directory exists
      # for non-existant files 
      non_existant_files.each do |path|
        mkdir_p File.dirname(path)
      end
      
      added_files.concat(non_existant_files)
      
      list
    end
    
    # Removes one or more directories.  Directories removed by rmdir
    # are restored upon an execution error.
    def rmdir(list)
      fu_list(list).collect do |dir|
        File.expand_path(dir)
      end.sort.reverse_each do |dir|
        unless Root.empty?(dir)
          raise "not an empty directory: #{dir}"
        end
        
        log :rmdir, dir, Logger::DEBUG
        if backed_up_files.include?(dir)
          FileUtils.rmdir(dir)
        else
          backup(dir, false)
        end
      end
    end
    
    # Removes one or more files.  Directories cannot be removed by this method.
    # Files removed by rm are restored upon an execution error.
    def rm(list) 
      fu_list(list).each do |path|
        path = File.expand_path(path)
        
        unless File.file?(path)
          raise "not a file: #{path}"
        end
        
        log :rm, path, Logger::DEBUG
        if backed_up_files.include?(path)
          FileUtils.rm(path)
        else
          backup(path, false)
        end
      end
    end
    
    # Removes one or more files.  If a directory is provided, it's contents are
    # removed recursively.  Files and directories removed by rm_r are restored
    # upon an execution error.
    def rm_r(list) 
      fu_list(list).collect do |path|
        File.expand_path(path)
      end.sort.reverse_each do |path|

        log :rm_r, path, Logger::DEBUG
        if backed_up_files.include?(path)
          FileUtils.rm_r(path)
        else
          backup(path, false)
        end
      end
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
    def rollback # :yields: error
      original_files = backed_up_files.keys
      original_files.sort.each do |path|
        restore(path, true)
      end
      
      (added_files.uniq - original_files).reverse_each do |path| 
        if File.file?(path)
          FileUtils.rm(path)
        elsif File.directory?(path)
          FileUtils.rmdir(path)
        end
      end
      
      backed_up_files.clear
      added_files.clear
    end
    
    # Removes backed-up files whose source matches the pattern.  Cleanup cannot
    # be rolled back and effectively prevents rollback.  By default, all 
    # backed_up_files are removed.
    def cleanup(pattern=/.*/)
      backed_up_files.each_pair do |source, target|
        next unless source =~ pattern
        FileUtils.rm backed_up_files.delete(source)
      end 
    end
    
    # Removes the directory if empty, and all empty parent directories.  This
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
      msg = fu_list(paths).collect {|path| File.basename(path) }.join(',')
      log(action, msg, level)
    end
    
    protected
    
    # Clears added_files and backed_up_files so that  
    # a failure will not affect previous executions
    def before_execute
      added_files.clear 
      backed_up_files.clear
    end
    
    # Removes made files/dirs and restores backed-up files upon 
    # an execute error.  Collects any errors raised along the way
    # and raises them in a Tap::Support::RunError.
    def on_execute_error(original_error)
      rollback_errors = []
      if rollback_on_error
        rollback {|error| rollback_errors << error}
      end

      # Re-raise the error if no rollback errors occured,
      # otherwise, raise a RunError tracking the errors.
      if rollback_errors.empty?
        raise original_error
      else
        rollback_errors.unshift(original_error)
        raise RollbackError.new(rollback_errors.join("\n"))
      end
    end
    
    class RollbackError < Exception
    end
    
    # Patterned from FileUtils
    def fu_list(arg)  
      [arg].flatten
    end
  end
end

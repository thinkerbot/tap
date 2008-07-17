require 'tap/support/shell_utils'

module Tap
  
  # == Overview
  #
  # FileTask provides methods for creating/modifying files such that you can
  # rollback changes if an error occurs.  In addition, FileTask provides a 
  # method to infer filepaths within the standard Tap directory structure.  
  #
  # === Creating Files/Rolling Back Changes
  #
  # FileTask tracks which files to roll back using the added_files array
  # and the backed_up_files hash.  On an execute error, all added files are
  # removed and then all backed up files (backed_up_files.keys) are restored  
  # using the corresponding backup files (backed_up_files.values). 
  # 
  # For consistency, all filepaths in added_files and backed_up_files should 
  # be expanded using File.expand_path.  The easiest way to ensure files are
  # properly set up for rollback is to use prepare before working with files
  # and to create directories with mkdir.
  #
  #   # this file will be backed up and restored
  #   File.open("file.txt", "w") {|f| f << "original content"}
  #  
  #   t = FileTask.new do |task|
  #     task.mkdir("some/dir")                         # marked for rollback
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
  class FileTask < Task
    include Tap::Support::ShellUtils
    
    autoload(:FileUtils, "fileutils")
    
    # A block used to infer filepaths. (see FileTask#filepath)
    attr_reader :inference_block
    
    # A hash of backup (source, target) pairs, such that the
    # backed-up files are backed_up_files.keys and the actual
    # backup files are backed_up_files.values.  All filepaths
    # in backed_up_files should be expanded.
    attr_reader :backed_up_files
    
    # An array of files added during task execution.  
    attr_reader :added_files
    
    # The directory name used when infering filepaths.  By
    # default dirname for an unbatched task is task.name,
    # or "#{task.name}_#{batch_index}" for a batched task.
    # (see FileTask#default_dirname)
    attr_accessor :dirname
    
    # The backup directory, defaults to the class backup_dir 
    config :backup_dir, :backup
    
    # A timestamp format used to mark backup files, defaults 
    # to the class backup_timestamp 
    config :backup_timestamp, "%Y%m%d_%H%M%S"
    
    # A flag indicating whether or not to rollback changes on 
    # error, defaults to the class rollback_on_error 
    config :rollback_on_error, true
    
    def initialize(*args)
      super
      
      batch.each do |task|
        task.dirname = task.default_dirname
        task.backed_up_files = {}
        task.added_files = []
        task.inference_block = nil
      end
    end
    
    # A batch File.open method.  If a block is given, each file in the list will be 
    # opened the open files passed to the block.  Files are automatically closed when 
    # the block returns.  If no block is given, the open files are returned.
    #
    #   task.open(["one.txt", "two.txt"], "w") do |one, two|
    #     one << "one"
    #     two << "two"
    #   end
    #
    #   File.read("one.txt")                 # => "one"
    #   File.read("two.txt")                 # => "two"
    #
    # Note that open normally takes and passes a list (ie an Array).  If you provide
    # a single argument, it will be translated into an Array, and passed AS AN ARRAY
    # to the block.
    #
    #   task.open("file.txt", "w") do |array|
    #     array.first << "content"
    #   end
    #
    #   File.read("file.txt")                # => "content"
    def open(list, mode="rb")
      open_files = []
      begin
        [list].flatten.map {|path| path.to_str }.each do |filepath| 
          open_files << File.open(filepath, mode)
        end

        block_given? ? yield(open_files) : open_files
      ensure
        open_files.each {|file| file.close } if block_given?
      end
    end
    
    # Returns the basename of path, exchanging the extension 
    # with extname, if provided.
    #
    #   task.basename('path/to/file.txt')           # => 'file.txt'
    #   task.basename('path/to/file.txt', '.html')  # => 'file.html'
    def basename(path, extname=nil)
      basename = File.basename(path)
      unless extname == nil
        extname = $1 if extname =~ /^\.?(.*)/
        basename = "#{basename.chomp(File.extname(basename))}.#{extname}"
      end
      basename
    end
    
    # Sets a block to perform path inference.  Raises an error if inference_block 
    # is already set, unless override = true.    
    def inference(override=false, &block) # :yields: app[dir], dirname, *paths
      raise "Inference block for task already set: #{name}" unless inference_block.nil? || override
      self.inference_block = block
    end
    
    # Infers a path using the inference block, or by using app.filepath if
    # no inference block is given.  Note the actual inputs to the inference
    # block are the application directory identified by dir, the dirname
    # for the task, and the provided paths.
    #
    #   t = FileTask.new 
    #   t.app[:data]                        # => "/data"
    #   t.dirname                           # => "tap/file_task"
    #   t.filepath(:data, "result.txt")     # => "/data/tap/file_task/result.txt"
    #
    #   t.inference do |root, dir, path|
    #     File.join(root, dir, path.chomp(".txt") + ".yml")
    #   end
    #
    #   t.filepath(:data, "result.txt")     # => "/data/tap/file_task/result.yml"
    #
    def filepath(dir, *paths) 
      inference_block ? 
        inference_block.call(app[dir], dirname, *paths) : 
        app.filepath(dir, dirname, *paths)
    end
    
    # Makes a backup filepath relative to backup_dir by translating the input
    # filepath and inserting a timestamp formatted using backup_timestamp.
    # The filepath used during translation will be the filepath relative
    # to dirname (if the input filepath is relative to dirname) or just 
    # the basename of the filepath.  
    #
    #   t = FileTask.new("dir/name", :backup_dir => :backup, :backup_timestamp => "%Y%m%d")
    #   t.dirname                                        # => "dir/name"
    #   t.app[:backup]                                   # => "/backup"
    #   Date.today.to_s                                  # => "2007-08-08"
    #
    #   # uses path relative to dirname, if possible
    #   t.backup_filepath("dir/name/folder/file.txt")    # => "/backup/folder/file_20070808.txt"
    #
    #   # otherwise uses basename
    #   t.backup_filepath("path/to/folder/file.txt")     # => "/backup/file_20070808.txt"
    #   
    def backup_filepath(filepath)
      extname = File.extname(filepath)
      backup_path = File.expand_path("#{filepath.chomp(extname)}_#{Time.now.strftime(backup_timestamp)}#{extname}")
      
      split_index = backup_path.index(dirname + "/")
      backup_path = split_index ? 
        backup_path[(split_index + dirname.length + 1)..-1] : 
        File.basename(backup_path)

      filepath(backup_dir, backup_path)
    end

    # Returns true if all of the targets are up to date relative to all of the sources
    # AND the task config_file, if it exists. Single values or arrays can be provided 
    # for both targets and sources.  Used to check if any work needs to be done for
    # a given set of sources and configurations.
    #
    # Returns false (ie 'not up to date') if +force?+ is true.
    def uptodate?(targets, sources=[])
      if app.options.force
        log_basename(:force, *targets)
        false
      else
        targets = [targets] unless targets.kind_of?(Array)
        sources = [sources] unless sources.kind_of?(Array)
        sources << config_file unless config_file == nil
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
    #   backed_up_file = t.backup(file).first   
    #       
    #   File.exists?(file)                       # => false
    #   File.exists?(backed_up_file)             # => true
    #   File.read(backed_up_file)                # => "file content"
    #
    #   File.open(file, "w") {|f| f << "new content"}
    #   t.restore(file)
    #
    #   File.exists?(file)                       # => true
    #   File.exists?(backed_up_file)             # => false
    #   File.read(file)                          # => "file content"
    #
    def backup(list, backup_using_copy=false)
      fu_list(list).collect do |filepath|
        next unless File.exists?(filepath)
        
        filepath = File.expand_path(filepath)
        if backed_up_files.include?(filepath)
          raise "Backup for #{filepath} already exists." 
        end
        
        target = File.expand_path(backup_filepath(filepath))
        dir = File.dirname(target)
        mkdir(dir)

        if backup_using_copy
          log :cp, "#{filepath} to #{target}", Logger::DEBUG
          FileUtils.cp(filepath, target)
        else
          log :mv, "#{filepath} to #{target}", Logger::DEBUG
          FileUtils.mv(filepath, target)
        end

        # track the target for restores
        backed_up_files[filepath] = target
        target
      end
    end
    
    # Restores each file in the input list using the backup file from
    # backed_up_files.  The backup directory is removed if it is empty.
    #  
    # Returns a list of the restored files.
    #
    #   file = "file.txt"
    #   File.open(file, "w") {|f| f << "file content"}
    #
    #   t = FileTask.new
    #   backed_up_file = t.backup(file).first   
    #       
    #   File.exists?(file)                       # => true
    #   File.exists?(backed_up_file)             # => true
    #   File.read(backed_up_file)                # => "file content"
    #
    #   File.open(file, "w") {|f| f << "new content"}
    #   t.restore(file)
    #
    #   File.exists?(file)                       # => true
    #   File.exists?(backed_up_file)             # => false
    #   File.read(file)                          # => "file content"
    #
    def restore(list)
      fu_list(list).collect do |filepath|
        filepath = File.expand_path(filepath)
        next unless backed_up_files.has_key?(filepath)

        target = backed_up_files.delete(filepath)
      
        dir = File.dirname(filepath)
        mkdir(dir)
        
        log :restore, "#{target} to #{filepath}", Logger::DEBUG
        FileUtils.mv(target, filepath, :force => true)

        dir = File.dirname(target)
        rmdir(dir)
        
        filepath
      end.compact
    end
    
    # Creates the directories in list if they do not exist and adds
    # them to added_files so they can be removed using rmdir.  Creating
    # directories in this way causes them to be rolled back upon an
    # execution error.
    #
    # Returns the made directories.
    #
    #   t = FileTask.new do |task, inputs|
    #     File.exists?("path")                  # => false
    #
    #     task.mkdir("path/to/dir")             # will be rolled back
    #     File.exists?("path/to/dir")           # => true
    #
    #     FileUtils.mkdir("path/to/another")    # will not be rolled back
    #     File.exists?("path/to/another")       # => true
    #
    #     raise "error!"
    #   end
    #
    #   begin
    #     t.execute(nil)
    #   rescue
    #     $!.message                            # => "error!"
    #     File.exists?("path/to/dir")           # => false
    #     File.exists?("path/to/another")       # => true
    #   end
    #    
    def mkdir(list)
      fu_list(list).each do |dir|
        dir = File.expand_path(dir)
        
        make_paths = []
        while !File.exists?(dir)
          make_paths << dir
          dir = File.dirname(dir)
        end
      
        make_paths.reverse_each do |path|
          log :mkdir, path, Logger::DEBUG 
          FileUtils.mkdir(path) 
          added_files << path 
        end
      end
    end
    
    # Removes each directory in the input list, provided the directory is in
    # added_files and the directory is empty.  When checking if the directory
    # is empty, rmdir checks for regular files and hidden files.  Removed
    # directories are removed from added_files.
    #
    # Returns a list of the removed directories.
    #
    #   t = FileTask.new
    #   File.exists?("path")                  # => false  
    #   FileUtils.mkdir("path")               # will not be removed
    #
    #   t.mkdir("path/to/dir")           
    #   File.exists?("path/to/dir")           # => true
    #
    #   t.rmdir("path/to/dir")                
    #   File.exists?("path")                  # => true  
    #   File.exists?("path/to")               # => false  
    def rmdir(list) 
      removed = []
      fu_list(list).each do |dir|  
        dir = File.expand_path(dir)
      
        # remove directories and parents until the
        # directory was not made by the task 
        while added_files.include?(dir)
          break unless Dir.entries(dir).delete_if {|d| d == "." || d == ".."}.empty?
          
          if File.exists?(dir)
            log :rmdir, dir, Logger::DEBUG
            FileUtils.rmdir(dir) 
          end
        
          removed << added_files.delete(dir)
          dir = File.dirname(dir)
        end
      end
      removed
    end
    
    # Prepares the input list of files by backing them up (if they exist),
    # ensuring that the parent directory for the file exists, and adding
    # each file to added_files.  As a result the files can be removed 
    # using rm, restored using restore, and will be rolled back upon an 
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
      list = fu_list(list)
      existing_files, non_existant_files = list.partition do |filepath| 
        File.exists?(filepath)
      end
      
      # backup existing files
      existing_files.each do |filepath|
        backup(filepath, backup_using_copy)
      end
      
      # ensure the parent directory exists  
      # for non-existant files 
      non_existant_files.each do |filepath| 
        dir = File.dirname(filepath)
        mkdir(dir)
      end
      
      list.each do |filepath|
        added_files << File.expand_path(filepath)
      end
   
      list
    end
    
    # Removes each file in the input list, provided the file is in added_files.  
    # The parent directory of each file is removed using rmdir. Removed files 
    # are removed from added_files.
    #
    # Returns the removed files and directories.
    #
    #   t = FileTask.new
    #   File.exists?("path")                  # => false  
    #   FileUtils.mkdir("path")               # will not be removed
    #
    #   t.prepare("path/to/file.txt")          
    #   FileUtils.touch("path/to/file.txt") 
    #   File.exists?("path/to/file.txt")      # => true
    #
    #   t.rm("path/to/file.txt")               
    #   File.exists?("path")                  # => true  
    #   File.exists?("path/to")               # => false
    def rm(list) 
      removed = []
      fu_list(list).each do |filepath|  
        filepath = File.expand_path(filepath)
        next unless added_files.include?(filepath)
        
        # if the file exists, remove it
        if File.exists?(filepath)
          log :rm, filepath, Logger::DEBUG
          FileUtils.rm(filepath, :force => true) 
        end

        removed << added_files.delete(filepath)
        removed.concat rmdir(File.dirname(filepath))
      end
      removed
    end
    
    # Rolls back changes by removing added_files and restoring backed_up_files.
    # Rollback is performed on an execute error if rollback_on_error == true,
    # but is provided as a separate method for flexibility when needed.
    # Yields errors to the block, which must be provided.
    def rollback # :yields: error
      added_files.dup.each do |filepath| 
        begin
          case
          when File.file?(filepath)
            rm(filepath)
          when File.directory?(filepath)
            rmdir(filepath)
          else
            # assures non-existant files are cleared from added_files
            # this is automatically done by rm and rmdir for existing files
            added_files.delete(filepath)
          end
        rescue
          yield $!
        end
      end
   
      backed_up_files.keys.each do |filepath|
        begin
          restore(filepath)
        rescue
          yield $!
        end
      end
    end
    
    # Removes backed-up files matching the pattern.
    def cleanup(pattern=/.*/)
      backed_up_files.each do |filepath, target|
        next unless target =~ pattern
        
        # the filepath needs to be added to added_files
        # before it can be removed by rm
        added_files << target
        rm(target)
        backed_up_files.delete(filepath)
      end 
    end
    
    # Logs the given action, with the basenames of the input filepaths.  
    def log_basename(action, filepaths, level=Logger::INFO)
      msg = case filepaths
      when Array then filepaths.collect {|filepath| File.basename(filepath) }.join(',')
      else
        File.basename(filepaths)
      end
      
      log(action, msg, level)
    end
    
    protected

    attr_writer :inference_block, :backed_up_files, :added_files
  
    # The default_dirname is based on the name of the task, and the
    # index of the task in batch (if the task is batched):
    #
    #   t = FileTask.new "name"
    #   t.default_dirname           # => "name"
    #
    #   t = FileTask.new "batched"
    #   t.batch[0].default_dirname  # => "name_0"
    #   t.batch[1].default_dirname  # => "name_1"
    def default_dirname
      batched? ? "#{name}_#{batch_index}" : name
    end
    
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
        raise Support::RunError.new(rollback_errors)
      end
    end
    
    # Lifted from FileUtils
    def fu_list(arg)  
      [arg].flatten.map {|path| path.to_str }
    end
  end
end

require 'tap/root'
require 'fileutils'
require 'tempfile'
require 'tap/templater'

module Tap

  module Test
    module Utils
      module_function
      
      # Generates an array of [source, reference] pairs mapping source
      # files to reference files under the source and reference dirs,
      # respectively.  Only files under source dir matching the pattern
      # will be mapped.  Mappings are either (in this order):
      #
      # - the path under reference_dir contained in the source file
      # - a direct translation of the source file from the source to
      #   the reference dir, minus the extname
      #
      # Notes:
      # - Source files may contain comments but should otherwise
      #   consist only of indentation (which is stripped) and
      #   the reference path.
      # - If a mapped path cannot be found, dereference raises  
      #   a DereferenceError.
      #
      # === example
      #
      #   root
      #   |- input
      #   |   |- dir.ref
      #   |   |- ignored.txt
      #   |   |- one.txt.ref
      #   |   `- two.txt.ref
      #   `- ref
      #       |- dir
      #       |- one.txt
      #       `- path
      #           `- to
      #               `- two.txt
      #
      # The 'two.txt.ref' file contains a reference path:
      #
      #  File.read('/root/input/two.txt.ref')    # => 'path/to/two.txt'
      #
      # Now:
      #
      #  reference_map('/root/input', '/root/ref')
      #  # => [
      #  # ['/root/input/dir.ref',     '/root/ref/dir'],
      #  # ['/root/input/one.txt.ref', '/root/ref/one.txt'],
      #  # ['/root/input/two.txt.ref', '/root/ref/path/to/two.txt']]
      #
      # And since no path matches 'ignored.txt':
      #
      #  reference_map('/root/input', '/root/ref', '**/*.txt')     
      #  # !> DereferenceError
      #
      def reference_map(source_dir, reference_dir, pattern='**/*.ref')
        source_root = Root.new(source_dir)
        reference_root = Root.new(reference_dir)
        source_root.glob(pattern).sort.collect do |source|
          # use the path specified in the source file
          relative_path = File.read(source).gsub(/#.*$/, "").strip
          
          # use the relative filepath of the source file to the
          # source dir (minus the extname) if no path is specified
          if relative_path.empty?
            relative_path = source_root.rp(source).chomp(File.extname(source))
          end
          
          reference = reference_root.path(relative_path)
          
          # raise an error if no reference file is found
          unless File.exists?(reference)
            raise DereferenceError, "no reference found for: #{source}"
          end

          [source, reference]
        end
      end
      
      # Dereferences source files with reference files for the duration
      # of the block.  The mappings of source to reference files are
      # determined using reference_map; dereferenced files are at the
      # same location as the source files, but with the '.ref' extname
      # removed.
      #
      # Notes:
      # - The reference extname is implicitly specified in pattern;
      #   the final extname of the source file is removed during
      #   dereferencing regardless of what it is.
      #
      def dereference(source_dirs, reference_dir, pattern='**/*.ref', tempdir=Dir::tmpdir)
        mapped_paths = []
        begin
          [*source_dirs].each do |source_dir|
            reference_map(source_dir, reference_dir, pattern).each do |source, reference|
              
              # move the source file to a temporary location
              tempfile = Tempfile.new(File.basename(source), tempdir)
              tempfile.close
              FileUtils.mv(source, tempfile.path)
              
              # copy the reference to the target
              target = source.chomp(File.extname(source))
              FileUtils.cp_r(reference, target)
              
              mapped_paths << [target, source, tempfile]
            end
          end unless reference_dir == nil
          
          yield
          
        ensure
          mapped_paths.each do |target, source, tempfile|
            # remove the target and restore the original source file
            FileUtils.rm_r(target) if File.exists?(target)
            FileUtils.mv(tempfile.path, source)
          end
        end
      end
      
      # Uses a Tap::Templater to template and replace the contents of path, 
      # for the duration of the block.  The attributes will be available in the
      # template context.
      def template(paths, attributes={}, tempdir=Dir::tmpdir)
        mapped_paths = []
        begin
          [*paths].each do |path|
            # move the source file to a temporary location
            tempfile = Tempfile.new(File.basename(path), tempdir)
            tempfile.close
            FileUtils.cp(path, tempfile.path)
              
            # template the source file
            content = File.read(path)
            File.open(path, "wb") do |file|
              file << Templater.new(content, attributes).build
            end
            
            mapped_paths << [path, tempfile]
          end

          yield
          
        ensure
          mapped_paths.each do |path, tempfile|
            # restore the original source file
            FileUtils.rm(path) if File.exists?(path)
            FileUtils.mv(tempfile.path, path)
          end
        end
      end
      
      # Raised when no reference can be found for a reference path.
      class DereferenceError < StandardError
      end
    end
  end
end

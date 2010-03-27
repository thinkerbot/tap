require 'tap/generator/base'

module Tap
  module Generator
    module Generators
      # :startdoc::generator make a faster tap
      class Tap < Tap::Generator::Base
        
        config :install, false, &c.flag     # install generated executable
        config :profile, '~/.bash_profile',
           &c.string                        # the name of the profile file (install only)
        
        def manifest(m)
          if Gem.source_index.find_name('tap').empty?
            raise "cannot generate tap unless the tap gem is installed"
          end
          
          original = `which tap`.strip
          backup = "#{original}.bak"
          executable = 'tap'
          
          m.template executable, 'tap.erb', {
            :generator => self.class,
            :install => install,
            :original => original,
            :backup => backup, 
            :load_paths => load_paths('lazydoc', 'configurable', 'tap'),
            :bin_path => Gem.bin_path('tap', 'tap')
          }
          
          profile_path = 'bash_profile'
          profile_original = File.expand_path(profile)
          profile_backup = "#{profile_original}.bak"
          m.template profile_path, 'bash_profile.erb', {
            :generator => self.class,
            :install => install,
            :original => profile_original,
            :backup => profile_backup
          }
          
          return unless install
          
          m.on(:generate) do 
            do_install(executable, original, backup)
            do_install(profile_path, profile_original, profile_backup)
          end
          
          m.on(:destroy) do 
            do_uninstall(original, backup)
            do_uninstall(profile_original, profile_backup)
          end
        end
        
        def do_install(path, original, backup)
          if File.exists?(backup)
            raise "backup file already exists: #{backup}"
          end
          
          mode = File.stat(original).mode
          uid = File.stat(original).uid
          gid = File.stat(original).gid
          
          mv(original, backup)
          mv(path, original)
          chmod(mode, original)
          chown(uid, gid, original)
        end
        
        def do_uninstall(original, backup)
          unless File.exists?(backup)
            raise "could not find backup file to restore: #{backup}"
          end
          
          mode = File.stat(original).mode
          uid = File.stat(original).uid
          gid = File.stat(original).gid
          
          rm(original)
          mv(backup, original)
          chmod(mode, original)
          chown(uid, gid, original)
        end
        
        def rm(path)
          log :rm, path
          FileUtils.rm(path)
        end
        
        def mv(src, target)
          log :mv, "#{src} -> #{target}"
          FileUtils.mv(src, target)
        end
        
        def chmod(mode, path)
          log :chmod, path
          FileUtils.chmod(mode, path)
        end
        
        def chown(uid, gid, path)
          log :chown, path
          File.chown(uid, gid, path)
        end
        
        def load_paths(*gem_names)
          load_paths = []
          
          gem_names.each do |gem_name|
            loaded_spec = Gem.source_index.find_name(gem_name).find do |spec|
              spec.loaded
            end

            gem_root = loaded_spec.full_gem_path
            loaded_spec.require_paths.each do |path|
              load_paths << File.expand_path(path, gem_root)
            end
          end
          
          load_paths
        end
      end 
    end
  end
end

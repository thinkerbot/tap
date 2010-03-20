require File.expand_path('../rap_test_helper', __FILE__)

class RapTest < Test::Unit::TestCase
  root = File.expand_path('../../..', __FILE__)
  
  acts_as_file_test
  acts_as_shell_test(
    :cmd_pattern => "% tap", 
    :cmd => [
      "ruby",
      "-I'#{root}/configurable/lib'",
      "-I'#{root}/lazydoc/lib'",
      "-I'#{root}/tap/lib'",
      "-I'#{root}/rap/lib'",
      "'#{root}/tap/bin/tap'"
    ].join(" "),
    :env => {
      'TAP_GEMS' => ''
    }
  )
  
  def setup
    super
    @current_dir = Dir.pwd
    method_root.chdir('.', true)
  end
  
  def teardown
    Dir.chdir(@current_dir)
    super
  end

  def test_declarations_make_help_available
    method_root.prepare('tapfile') do |file|
      file << %q{
      require 'rap'
      include Rap::Declarations
      namespace :rap_test do
        # :: task summary
        # long description
        task :task_with_doc
      
        # ::
        task :task_with_empty_desc
        task :task_without_doc
      
        desc "desc"
        task :task_with_desc
        
        task :task_with_config, :key => 'value'
        
        task :task_without_args
        task :task_with_args, :a, :b
      end
      }
    end
    
    sh_match "% tap task_with_doc --help",
      /RapTest::TaskWithDoc -- task summary/,
      /long description/

    sh_match "% tap task_with_empty_desc --help",
      /RapTest::TaskWithEmptyDesc\s+usage/m

    sh_match "% tap task_without_doc --help",
      /RapTest::TaskWithoutDoc\s+usage/m
      
    sh_match "% tap task_with_desc --help",
      /RapTest::TaskWithDesc -- desc/
      
    sh_match "% tap task_with_config --help",
      /RapTest::TaskWithConfig/,
      /--key KEY/,
      /--config FILE/
      
    sh_match "% tap task_without_args --help", 
      /RapTest::TaskWithoutArgs\s*$/
    
    sh_match "% tap task_with_args --help", 
      /RapTest::TaskWithArgs A B\s*$/
  end

  def test_rap_help_with_duplicate_nested_declarations
    method_root.prepare('tapfile') do |file|
      file << %q{
      require 'rap'
      include Rap::Declarations

      desc "first desc"
      task :task

      namespace :sample do
        desc "first desc"
        task :task

        desc "second desc"
        task :task
      end
      }
    end

    sh_match "% tap task --help", /first desc/
    sh_match "% tap sample/task --help", /second desc/
  end
  
  def test_rap_runs_rap_tasks_from_tapfile
    method_root.prepare('tapfile') do |file|
      file << %q{
        require 'rap'
        Rap.task(:echo) { puts 'echo!' }
      }
    end
    
    sh_test %q{
    % tap echo
    echo!
    }
  end

  def test_rap_behaves_much_as_rake
    method_root.prepare('tapfile') do |file|
      file << %q{
      require 'rap'
      include Rap::Declarations

      task(:a) { puts 'A' }
      task(:b => :a) { puts 'B' }
      task(:c, :str) {|task, args| puts "#{args.str.upcase}" }

      namespace :ns do
        task(:a) { puts 'nsA' }
        task(:b => 'ns/a') { puts 'nsB' }
        task(:c, :str) {|task, args| puts "ns#{args.str.upcase}" }
      end
      }
    end
    
    sh_test %Q{
    % tap a
    A
    }

    sh_test %Q{
    % tap b
    A
    B
    }
    
    sh_test %Q{
    % tap c arg
    ARG
    }
    
    sh_test %Q{
    % tap ns/a
    nsA
    }
    
    sh_test %Q{
    % tap ns/c arg -- ns/b -- ns/a -- b
    nsARG
    nsA
    nsB
    A
    B
    }
  end
end
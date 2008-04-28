# this is the same code as in rake/rake_test_loader.rb
# except it duplicates ARGV before iterating over it.
#
# This prevents an error in Ruby 1.9 when one of the 
# loaded files attempts to modify ARGV.  In that case
# you get an error like: 'can't modify array during 
# iteration (RuntimeError)'
ARGV.dup.each { |f| load f unless f =~ /^-/  }

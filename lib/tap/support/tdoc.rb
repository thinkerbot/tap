
module Tap
  module Support
    #module TDoc
      
    #end
  end
end


# == Overview
# Lazydoc hooks into and extends RDoc to make task documentation available for command line
# applications as well as for inclusion in RDoc html.  In particular, Lazydoc makes available
# documentation for Task configurations, when they are present.  Lazydoc provides an extension
# to the standard RDoc HTMLGenerator and template.  
#
# === Usage
# To generate task documentation with configuration information, Lazydoc must be loaded and 
# the appropriate flags passed to rdoc .  Essentially what you want is:
#
#   % rdoc --fmt tdoc --template tap/support/tdoc/tdoc_html_template [file_names....]
#
# Unfortunately, there is no way to load or require a file into the rdoc utility directly; the 
# above code causes an 'Invalid output formatter' error.  However, Lazydoc is easy to utilize 
# from a Rake::RDocTask:
#
#   require 'rake'
#   require 'rake/rdoctask'
#
#   desc 'Generate documentation.'
#   Rake::RDocTask.new(:rdoc) do |rdoc|
#     require 'tap/support/tdoc'
#     rdoc.template = 'tap/support/tdoc/tdoc_html_template' 
#     rdoc.options << '--fmt' << 'tdoc'
#  
#     # specify whatever else you need
#     # rdoc.rdoc_files.include(...)
#   end
#
# Now execute the rake task like:
#
#   % rake rdoc
#
# Lazydoc may also be utilized programatically, but you should be aware that RDoc in Ruby
# can raise errors and/or cause namespace conflicts (see below).
#
# === Implementation
# RDoc is a beast to utilize in a  non-standard way.  One way to make RDoc parse unexpected
# flags like 'config_accessor' or the 'c' config specifier is to use the '--accessor' option
# (see 'rdoc --help' or the RDoc documentation for more details).  
#
# Lazydoc hooks into the '--accessor' parsing process to pull out configuration attributes and
# format them into their own Configuration section on an RDoc html page.  When 'tdoc' is
# specified as an rdoc option, Lazydoc in effect sets accessor flags for all the standard Task
# configuration methods, and then extends the RDoc::RubyParser handle these specially.  
#
# If 'tdoc' is not specified as the rdoc format, Lazydoc does not affect the RDoc output.
# Similarly, the configuration attributes will not appear in the output unless you specify a 
# template that utilizes them.
#
# === Namespace conflicts
# RDoc creates a namespace conflict with other libraries that define RubyToken and RubyLex
# in the Object namespace (the prime example being IRB).  Lazydoc checks for such a conflict
# and redfines the RDoc RubyToken and RubyLex within the RDoc namespace. Essentially:
#
#   RubyToken => RDoc::RubyToken
#   RubyLex => RDoc::RubyLex
#
# The redefinition should not affect the existing RubyToken and RubyLex constants, but if 
# you directly use the RDoc versions after loading Lazydoc, you should be aware that they must 
# be accessed through the new constants.  Unfortunatley the trick is not seamless.  The RDoc 
# RubyLex makes a few calls to the RubyLex class method 'debug?'... these will be issued to 
# the existing RubyLex method and not RDoc::RubyLex.debug?
#
# In addition, because of the RubyLex calls, the RDoc::RubyLex cannot be fully hidden when 
# Lazydoc is loaded before the conflicting RubyLex; you cannot load Lazydoc before loading IRB 
# without raising warnings.  I hope to submit a patch for RDoc to stop this nonsense in the 
# future.
#
# On the plus side, you can now access/use RDoc within irb by requiring 'tap/support/tdoc'.
#

# try to parse arguments from the process method
# if no args have been explicitly stated for a 
# particular tdoc.  this is a tricky thing to do
# without having knowledge of the ruby code (as
# Lazydoc attempts to do, to speed parsing), and
# requires an assumption for the case where multiple
# tdocs are present in a single string. Assumption:
# - if the args are not explicitly stated, then
#   the process method will occur BETWEEN the
#   first declarations for a given tdoc.
#
# ex:
# :startdoc:::-
#
#   # First::Class::manifest
#   class First::Class
#     def process() end
#   end
#   # Second::Class::manifest
#   class Second::Class
#     def process() end
#   end
#
# rather than:
#
#   # First::Class::manifest
#   class First::Class
#     def process() end
#   end
#   class Second::Class
#     def process() end
#   end
#   # Second::Class::manifest
#
# :startdoc:::+
# def parse_process_args(scanner, range_begin, range_end)
# 
#   # parse for the process args, checking that the
#   # args are where they are expected to be
#   scanner.pos = range_begin
#   return nil unless scanner.skip_until(/^\s*def\s+process\(/) != nil
#     
#   args = scanner.scan_until(/\)/).to_s.chomp(')').split(',').collect do |arg|
#     arg = arg.strip.upcase
#     case arg
#     when /^&/ then nil
#     when /^\*/ then arg[1..-1] + "..."
#     else arg
#     end
# 
#   end.compact
# 
#   if args && scanner.pos >= range_end
#     raise "ranges for scanning process arguments are mixed"
#   end
#   
#   args
# end


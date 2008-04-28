# From: http://www.xxeo.com/archives/2007/06/page/2
#

require 'pathname'

$ArmMap = Hash.new("|   ")
$ArmMap[""] = ""

$ArmMap["`"] = "    "

def visit(path, leader, tie, arm, node)

  print "#{leader}#{arm}#{tie}#{node}\n"

  visitChildren(path + node, leader + $ArmMap[arm])

end

def visitChildren(path, leader)

  return unless FileTest.directory? path
  return unless FileTest.readable? path

  files = path.children(false).sort    #false = return name, not full path

  return if files.empty?

  arms = Array.new(files.length - 1, "|") << "`"

  pairs = files.zip(arms)
  pairs.each { |e|  visit(path, leader, "- ", e[1], e[0]) } 

end

ARGV << "." if ARGV.empty?

ARGV.map{ |path| visit Pathname.new("."), "","","",Pathname.new(path) }

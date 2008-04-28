# this checks to see that you can unset and reset 
# constants and retain the functionality of the
# constant.

module TestMod
  CONST = 1
  
  module_function
  
  def function
    puts "in function"
  end
end

class Object
  old_ruby_token = remove_const(:TestMod)
  const_set(:NewName, old_ruby_token )
end

puts NewName::CONST
puts NewName.function

puts "done"

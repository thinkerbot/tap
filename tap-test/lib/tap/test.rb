require 'test/unit'

# require the shims for the appropriate test suite
if Object.const_defined?(:MiniTest)
  require 'tap/test/setup/minitest'
else
  require 'tap/test/setup/testunit'
end

describe('Test preset parser', function()
  describe('macro expansion', function()
    local Parser = require('cmake.presets_parser')
    local Path = require('plenary.path')
    it('Some normal ones', function()
      local testPreset = {
        name = 'TestPreset',
        binaryDir = '${sourceDir}/some/${presetName}',
        binaryDir2 = '${sourceParentDir}',
        generator = 'ninja',
        description = 'Generator ${generator}',
      }
      local expected_source_dir = Path.new(vim.fn.getcwd())
      local expected_result = {
        name = 'TestPreset',
        binaryDir = expected_source_dir.filename .. '/some/TestPreset',
        binaryDir2 = expected_source_dir:parent().filename,
        generator = 'ninja',
        description = 'Generator ninja',
      }

      local result = Parser.new():macro_expand(testPreset)
      assert.are.same(result, expected_result)
    end)
    it('Expand environment variable', function()
      local preset = { name = '$env{HOME}' }
      local expectedResult = { name = vim.fn.getenv('HOME') }
      local result = Parser.new():macro_expand(preset)
      assert.are.same(result, expectedResult)
    end)
  end)
end)

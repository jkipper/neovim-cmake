describe('PresetParser: ', function()
  local Parser = require('cmake.presets_parser')
  local Path = require('plenary.path')
  local cwd = Path:new(vim.loop.cwd())
  describe('Macro expansion: ', function()
    it('Some normal ones', function()
      local test_preset = {
        name = 'test_preset',
        binaryDir = '${sourceDir}/some/${presetName}',
        generator = 'ninja',
        description = 'Generator ${generator} ${sourceParentDir}',
      }
      local expected_source_dir = cwd
      local expected_result = {
        name = 'test_preset',
        binaryDir = expected_source_dir:absolute() .. '/some/test_preset',
        generator = 'ninja',
        description = 'Generator ninja ' .. expected_source_dir:parent():absolute(),
      }

      local result = Parser.new():macro_expand(test_preset, cwd)
      assert.are.same(result, expected_result)
    end)
    it('Expand environment variable', function()
      local preset = { name = '$env{HOME}', binaryDir = '${sourceDir}' }
      local expected_result = { name = vim.fn.getenv('HOME'), binaryDir = vim.loop.cwd() }
      local result = Parser.new():macro_expand(preset, cwd)
      assert.are.same(result, expected_result)
    end)
  end)
  describe('Resolve inheritance', function()
    local default = {
      name = 'default',
      displayName = 'default config',
      description = 'base preset',
      generator = 'ninja',
      binaryDir = '/some/random/path',
    }
    it('Get correct binary dir', function()
      local configure_presets = {
        default = default,
        use = { name = 'use', displayName = 'preset to use', inherits = 'default', description = 'asdas' },
      }
      local expected_use = {
        name = 'use',
        displayName = 'preset to use',
        description = 'asdas',
        inherits = 'default',
        generator = default.generator,
        binaryDir = default.binaryDir,
      }

      local result = Parser.new():resolve_inheritance(configure_presets)
      assert.are.same(result, { default = configure_presets.default, use = expected_use })
    end)
    it("Don't inherit description or displayName", function()
      local configure_presets = {
        default = default,
        use = { name = 'use', inherits = 'default', generator = default.generator, binaryDir = default.binaryDir },
      }
      local expected_result = { name = 'use', inherits = 'default', generator = default.generator, binaryDir = default.binaryDir }
      local result = Parser.new():resolve_inheritance(configure_presets)
      assert.are.same(result['use'], expected_result)
    end)
  end)
end)

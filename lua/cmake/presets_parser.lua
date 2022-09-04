local Path = require('plenary.path')
local a = require('plenary.async')
local context_manager = require('plenary.context_manager')
local with = context_manager.with
local open = context_manager.open

local PresetParser = {}
PresetParser.__index = PresetParser

function PresetParser.new()
  local preset_files = {}
  return setmetatable({}, PresetParser)
end

--- Parse presets out of a file
---@param file Path
---@return table<string, table>
function PresetParser:get_presets(file)
  if not file:exists() then
    vim.notify('File' .. file .. 'does not exist')
    return {}
  end
  local content = file:read()
  local json = vim.json.decode(content)
  local presets = {
    configure = json['configurePresets'],
    build = json['buildPresets'],
    test = json['testPresets'],
  }
  return presets
end

function PresetParser:collect_configure_presets(configure_presets)
  local relevant_keys = { 'binaryDir', 'hidden', 'name', 'inherits', 'description', 'generator' }
  local collected = {}
  for _, preset in ipairs(configure_presets) do
    collected[preset.name] = {}
    for _, key in ipairs(relevant_keys) do
      collected[preset.name][key] = preset[key]
    end
  end
  return collected
end

function PresetParser:macro_expand(preset)
  local available_macros = {
    sourceDir = Path:new(vim.fn.getcwd()).filename, -- Not always accurate, but good enough for now
    sourceParentDir = Path:new(vim.fn.getcwd()):parent().filename,
    presetName = preset.name,
    generator = preset.generator,
    hostSystemName = '',
    dollar = '$',
    pathListSept = '/', -- make os specific
    -- ["$env{(*)}"] = function () return "LOAD" end
  }
  for key, value in pairs(preset) do
    preset[key] = value:gsub('%${(%w+)}', available_macros):gsub('%$env{(%w+)}', function(env) return vim.fn.getenv(env) end)
  end
  return preset
end

-- local parser = PresetParser.new()
-- local presets = parser:get_presets(Path:new(vim.fn.getcwd(), 'samples', 'C++ project', 'CMakePresets.json'))
-- local configure_presets = parser:collect_configure_presets(presets.configure)

-- local testPreset = {
--   name = 'TestPreset',
--   binaryDir = '${sourceDir}/some/${presetName}',
--   binaryDir2 = '${sourceParentDir}',
--   generator = 'ninja $env{HOME}',
--   description = 'Generator ${generator} ',
-- }

-- print(vim.inspect(parser:macro_expand(testPreset)))
return PresetParser
-- print(vim.inspect(configure_presets))

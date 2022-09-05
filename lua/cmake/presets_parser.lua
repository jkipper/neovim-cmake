local Path = require('plenary.path')
local a = require('plenary.async')
local context_manager = require('plenary.context_manager')
local with = context_manager.with
local open = context_manager.open

local PresetParser = {}
PresetParser.__index = PresetParser

function PresetParser.new() return setmetatable({}, PresetParser) end

---@alias ParsedPresets table<string, table>[]

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

--- Collect the relevant keys from the configure presets
---@param configure_presets table[]
---@return ParsedPresets
function PresetParser:collect_configure_presets(configure_presets)
  local relevant_keys = { 'displayName', 'binaryDir', 'hidden', 'name', 'inherits', 'description', 'generator' }
  local collected = {}
  for _, preset in ipairs(configure_presets) do
    collected[preset.name] = {}
    for _, key in ipairs(relevant_keys) do
      collected[preset.name][key] = preset[key]
    end
  end
  return collected
end

local is_windows = function() return vim.loop.os_uname().sysname:find('Windows') and true or false end
--- Expand any macro stored in a preset, as defined in the cmake spec: https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html#macro-expansion
---@param preset table
---@param file Path
---@return table
function PresetParser:macro_expand(preset, file)
  local available_macros = {
    sourceDir = Path:new(vim.loop.cwd()):absolute(), -- Not always accurate, but good enough for now
    sourceParentDir = Path:new(vim.loop.cwd()):parent():absolute(),
    presetName = preset.name,
    generator = preset.generator,
    hostSystemName = vim.loop.os_uname().sysname,
    fileDir = tostring(file:parent()),
    dollar = '$',
    pathListSep = is_windows() and ';' or ':',
  }
  for key, value in pairs(preset) do
    preset[key] = value:gsub('%${(%w+)}', available_macros):gsub('%$env{(%w+)}', function(env) return vim.fn.getenv(env) end)
  end
  return preset
end

--- Resolve the inheritance of binaryDir and generators
---@param presets ParsedPresets
---@return ParsedPresets
function PresetParser:resolve_inheritance(presets)
  ---@type table<string,table?>
  local result = {}
  for name, preset in pairs(presets) do
    local inherits = preset['inherits']
    if inherits ~= nil then
      local to_merge = { }
      if type(inherits) == 'string' then
        to_merge[#to_merge + 1] = presets[inherits]
      else
        for _, inherit_from in ipairs(inherits) do
          to_merge[#to_merge + 1] = preset[inherit_from]
        end
      end
      result[name] = self:_merge_presets(preset, to_merge)
    else
      result[name] = preset
    end
  end
  return result
end

function PresetParser:_merge_presets(start, presets)
  local result = start
  for _, value in ipairs(presets) do
    if result['generator'] == nil then
      result['generator'] = value['generator']
    end
    if result['binaryDir'] == nil then
      result['binaryDir'] = value['binaryDir']
    end
  end
  return result
end

return PresetParser

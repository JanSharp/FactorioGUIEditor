
-- Even though this file replaces the require function, it does not change its behavior.
-- `depends` however behaves slightly differently in that it allows circular references by
-- first returning a dummy table which gets populated once the required module finished loading.
-- This does apply some restrictions to the required module:
-- - It must return a table
-- - The table must only contain reference values or static non reference values.
--   Since all reference types except tables (and technically userdata) are immutable,
--   the only mutable data type in the table is a nested table.
-- The depending side also get some restrictions:
-- - It can only use any of the values of the required module after all top level functions are done
--   loading. In this case that basically means it must not use any of the values until some event
--   handler gets run, at which point it is guaranteed that all modules are done loading.

local real_require = require

local loading_modules = {}
local results = {}

local function depends_internal(module, allow_circular)
  if results[module] ~= nil then
    return results[module]
  end

  local loading_results = loading_modules[module]
  if loading_results then
    if not allow_circular then
      error("Circular require dependencies for module '"..module.."'.")
    end
    local loading_result = setmetatable({}, {
      __index = function()
        error("Attempt to index into module '"..module.."' before it was done loading.")
      end,
      __newindex = function()
        error("Attempt to assign to module '"..module.."' before it was done loading.")
      end,
    })
    loading_results[#loading_results+1] = loading_result
    return loading_result
  end

  loading_results = {}
  loading_modules[module] = loading_results
  local result = real_require(module)
  loading_modules[module] = nil
  results[module] = result
  if not loading_results[1] then
    return result
  end

  if type(result) ~= "table" then
    error("Modules loaded using 'depends' must return a table. module: '"..module.."'.")
  end
  for _, loading_result in ipairs(loading_results) do
    setmetatable(loading_result, nil)
    for k, v in pairs(result) do
      loading_result[k] = v
    end
    setmetatable(loading_result, getmetatable(result))
  end
  return result
end

-- Factorio mod debugger support
---@diagnostic disable-next-line: undefined-global
if __DebugAdapter then __DebugAdapter.defineGlobal("depends") end

---@generic T
---@param module `T`
---@return T
function depends(module)
  return depends_internal(module, true)
end

---@generic T
---@param module `T`
---@return T
function require(module)
  return depends_internal(module, false)
end

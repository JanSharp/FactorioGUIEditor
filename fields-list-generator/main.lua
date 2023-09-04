#! /home/jmpc4/dev/phobos/bin/linux/lua

local json = require("json")
local serialize = require("serialize")

local machine_readable_docs_path = ...
if not machine_readable_docs_path then
  io.stderr:write("Missing first argument: Path to machine readable docs json file.")
  os.exit(false)
end

local file = assert(io.open(machine_readable_docs_path, "r"))
local contents = file:read("*a")
assert(file:close())

local docs = json.decode(contents)
if docs.api_version ~= 3 and docs.api_version ~= 4 then
  io.stderr:write("Can only read docs with api_version 3 or 4, got "..docs.api_version..".\n")
  os.exit(false)
end

local lua_gui_element_class
for _, class in ipairs(docs.classes) do
  if class.name == "LuaGuiElement" then
    lua_gui_element_class = class
    break
  end
end

file = assert(io.open("../mods/gui-editor/fields.lua", "w"))
assert(file:write(serialize(lua_gui_element_class.attributes)))
assert(file:close())

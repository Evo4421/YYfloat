package.path = package.path .. ";./?.lua;./lib/?.lua;./lib/sub/?.lua"

local lfs = require "lfs"
local cjson = require "cjson"

local config = require "config"

local Exports = {}

local list_file = io.open(config.PLUGINS_LIST, "r")
local list = cjson.decode(list_file:read("*a"))
list_file:close()

function Exports.exist(plugin_name)
  -- 检查一个插件是否存在
  if type(plugin_name) ~= "string" or plugin_name == "" then return false end
  if plugin_name:find("[/\\]") or plugin_name:find("%.%.") then return false end

  for key, _ in pairs(list) do
    if plugin_name == key then
      return true
    else
      return false
    end
  end

  local plugin_path = config.PLUGINS_DIR .. "/" .. plugin_name
  
  if lfs.attributes(plugin_path, "mode") ~= "directory" then return false end
  if lfs.attributes(plugin_path .. "/.yyfloat_flag", "mode") ~= "file" then return "occupied" end
  
  local required = {"/start.sh", "/manifest.json"}
  for i = 1, #required do
    if lfs.attributes(plugin_path .. required[i], "mode") ~= "file" then return "damaged" end    
  end

  return true
end

function Exports.search(data, query)
   -- 根据搜索词搜索名称，作者，标签和关键词，搜到返回名称，反之则返回nil
  if type(data) ~= "table" then return {} end
  if type(query) ~= "string" or query:match("^%s*$") then
    return {}
  end

  local results = {}

  for key, val in pairs(data) do
    local matched = false
    
    if key == query then
      matched = true
    end

    if not matched and type(val) == "table" then
      if val.author == query then
        matched = true
      end

      if not matched then
        local tag = val.tags
        if tag then
          for i = 1, #tag do
            if tag[i] == query then
              matched = true
              break
            end
          end
        end
      end

      if not matched then
        local keywords = val.keywords
        if keywords then
          for i = 1, #keywords do
            if keywords[i] == query then
              matched = true
              break
            end
          end
        end
      end
    end

    if matched then
      results[#results + 1] = key
    end
  end

  return results
end
#!/usr/bin/env lua

--- YYfloat 插件模块
-- 负责插件存在性检查、搜索、启动脚本执行。
-- 元数据采用惰性加载：每次调用都重新读取 PLUGINS_LIST，
-- 避免模块加载期读文件导致"首次运行崩溃"与"元数据过期(stale)"问题。
-- @module plugin


local config = require "config"
local core = require "core"

local Exports = {}

--- 惰性读取本地插件元数据表
-- @treturn table 插件表 { [plugin_name] = { author=..., version=..., ... } }
local function get_list()
  local data = core.read_json(config.PLUGINS_LIST)
  if type(data) ~= "table" then return {} end
  return data
end

--- 判断插件是否存在 / 是否被占用 / 是否损坏
-- @tparam string plugin_name 插件名称
-- @treturn boolean|string true=正常; false=不存在; "occupied"=目录被占用; "damaged"=文件缺失
function Exports.exist(plugin_name)
  -- 名称白名单校验（防路径穿越 / 注入）
  if not core.validate_name(plugin_name) then return false end

  local list = get_list()
  if not list[plugin_name] then return false end

  local plugin_path = config.PLUGINS_DIR .. "\\" .. plugin_name
  if not core.is_dir(plugin_path) then return false end

  -- 归属标记缺失 → 目录被其他程序占用
  if not core.file_exists(plugin_path .. "\\" .. config.MARKER_FILE) then
    return "occupied"
  end

  -- 必需文件缺失 → 插件损坏
  for i = 1, #config.REQUIRED_FILES do
    if not core.file_exists(plugin_path .. config.REQUIRED_FILES[i]) then
      return "damaged"
    end
  end
  return true
end

--- 按名称/作者/标签/关键词搜索插件
-- @tparam table data 远端插件表
-- @tparam string query 搜索词
-- @treturn table 命中的插件名列表
function Exports.search(data, query)
  if type(data) ~= "table" then return {} end
  if type(query) ~= "string" or query:match("^%s*$") then return {} end

  local results = {}
  for key, val in pairs(data) do
    local matched = (key == query)

    if not matched and type(val) == "table" then
      if val.author == query then matched = true end

      if not matched and val.tags then
        for i = 1, #val.tags do
          if val.tags[i] == query then matched = true break end
        end
      end

      if not matched and val.keywords then
        for i = 1, #val.keywords do
          if val.keywords[i] == query then matched = true break end
        end
      end
    end

    if matched then results[#results + 1] = key end
  end
  return results
end

--- 启动插件
-- 从 manifest.json 读取 windows-start 配置项作为启动命令
-- @tparam string name 插件名称
-- @tparam table args 参数列表
-- @treturn boolean 是否成功
-- @treturn string|nil 错误说明
function Exports.open(name, args)
  if not core.validate_name(name) then
    return false, "[!] 非法的插件名称: " .. tostring(name)
  end

  local plugin_dir = config.PLUGINS_DIR .. "\\" .. name
  local manifest, merr = core.read_json(plugin_dir .. "\\manifest.json")
  if not manifest then
    return false, "[!] 无法读取 manifest.json: " .. tostring(merr)
  end

  local start_cmd = manifest["windows-start"]
  if not start_cmd or start_cmd == "" then
    return false, "[!] 该插件未配置 windows-start"
  end

  -- 参数转义
  local parts = {}
  for _, a in ipairs(args or {}) do
    parts[#parts + 1] = core.shell_escape(a)
  end

  -- 切换到插件目录执行启动命令
  local cmd = 'cd /d "' .. plugin_dir .. '" && ' .. start_cmd
  if #parts > 0 then cmd = cmd .. " " .. table.concat(parts, " ") end

  local ok, _, code = os.execute(cmd)
  if not ok then
    return false, "[!] 启动失败, 退出码: " .. tostring(code)
  end
  return true, nil
end

return Exports

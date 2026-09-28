#!/usr/bin/env lua

--- remove 命令：彻底删除一个插件
-- @module commands.remove

local lfs = require "lfs"

local config = require "config"
local core = require "core"

local M = {}

--- 删除插件
-- @tparam string name 插件名称
-- @treturn boolean 是否成功
-- @treturn string|nil 错误说明
function M.run(name)
  -- 名称白名单校验（必须）
  if not core.validate_name(name) then
    return false, "[!] 非法的插件名称，已拒绝删除: " .. tostring(name)
  end

  local plugin_dir = config.PLUGINS_DIR .. "/" .. name

  -- 必须位于插件目录内
  if plugin_dir:find("%.%.") then
    return false, "[!] 检测到危险路径，已拒绝删除"
  end

  -- 目录不存在 → 明确失败（原实现只提示不退出，会继续 rm -rf）
  if lfs.attributes(plugin_dir, "mode") ~= "directory" then
    return false, "[!] 该插件目录不存在，无需删除"
  end

  -- 归属标记校验：避免误删用户自建的同名目录
  if lfs.attributes(plugin_dir .. "/" .. config.MARKER_FILE, "mode") ~= "file" then
    return false, "[!] 目标目录缺少归属标记 " .. config.MARKER_FILE .. "，拒绝删除（防误删）"
  end

  -- 元数据读取
  local list = core.read_json(config.PLUGINS_LIST) or {}
  local meta = list[name]
  local size = meta and meta.size or "未知"

  -- 执行删除
  local ok, _, code = os.execute("rm -rf " .. core.shell_escape(plugin_dir))
  if not ok then
    return false, "[!] 删除插件目录失败, 退出码: " .. tostring(code)
  end

  -- 同步元数据
  list[name] = nil
  local wrote, werr = core.write_json(config.PLUGINS_LIST, list)
  if not wrote then return false, werr end

  print("[*] 成功删除 " .. name .. "\t总量: " .. tostring(size))
  return true, nil
end

return M

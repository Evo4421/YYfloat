#!/usr/bin/env lua

--- check 命令：检查指定插件的元数据与文件完整性
-- 修正：io.read → io.open；marker 名与 plugin.lua 统一。
-- @module commands.check

local semver = require "semver"

local config = require "config"
local core = require "core"

local M = {}

--- 检查插件状态
-- @tparam string name 插件名称
-- @treturn boolean 是否成功
-- @treturn string|nil 错误说明
function M.run(name)
  if not name then return false, "[!] 插件名称是必填的" end
  if not core.validate_name(name) then return false, "[!] 非法的插件名称" end

  print("[*] 正在检查 " .. name .. " 插件状态...")

  local list, lerr = core.read_json(config.PLUGINS_LIST)
  if not list then
    return false, "[!] 插件表文件损坏: " .. tostring(lerr) ..
      "\n修复建议: 删除 " .. config.PLUGINS_LIST .. "，然后重新安装插件以重建元数据"
  end

  local meta = list[name]
  if not meta then
    return false, "[!] 不存在插件 " .. name ..
      "\n修复建议: 如果该插件确实存在，请使用 yyfloat plugins install " .. name .. " 安装"
  end

  if not (meta.author and meta.version and meta.size) then
    return false, "[!] 插件元数据缺失，会导致 YYfloat 功能异常" ..
      "\n修复建议: 使用 yyfloat remove " .. name .. " 彻底删除后重装"
  end

  local plugin_dir = config.PLUGINS_DIR .. "/" .. name
  if not core.is_dir(plugin_dir) then
    return false, "[!] 插件已被标记，但其目录并不存在" ..
      "\n修复建议: 使用 yyfloat remove " .. name .. " 彻底删除后重装"
  end

  -- 必需文件检查（使用统一常量）
  for i = 1, #config.REQUIRED_FILES do
    local rel = config.REQUIRED_FILES[i]
    if not core.file_exists(plugin_dir .. rel) then
      return false, "[!] 插件必要文件缺失: " .. rel:sub(2) ..
        "\n修复建议: 使用 yyfloat remove " .. name .. " 彻底删除后重装"
    end
  end

  local manifest, merr = core.read_json(plugin_dir .. "/manifest.json")
  if not manifest then
    return false, "[!] manifest.json 无法解析: " .. tostring(merr)
  end

  if not (manifest.name and manifest.version and manifest.author) then
    return false, "[!] manifest.json 必填项缺失 (name/version/author)" ..
      "\n修复建议: 自己补上或重装插件"
  end

  local ok, verr = pcall(semver, manifest.version)
  if not ok then
    print("[!] manifest.json 版本号不合法: " .. tostring(verr))
    return false, nil
  end

  print("[*] " .. name .. " 状态正常 (v" .. tostring(manifest.version) .. ")")
  return true, nil
end

return M

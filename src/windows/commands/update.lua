#!/usr/bin/env lua

--- update 命令：更新 YYfloat 自身
-- 关键顺序：先备份旧版本 → 再切换软链接（原实现顺序相反，会备份到新版本）。
-- @module commands.update

local semver = require "semver"

local config = require "config"
local core = require "core"

local M = {}

--- 执行更新流程
-- @treturn boolean 是否成功
-- @treturn string|nil 错误说明
function M.run()
  local body, code, err = core.http_get(config.MANIFEST_URL)
  if not body then return false, err end
  if code ~= 200 then return false, "[!] 拉取配置表失败: HTTP " .. tostring(code) end

  local ok, root = pcall(require("dkjson").decode, body)
  if not ok then return false, "[!] 无法解析配置表" end

  -- 修正：先整体 decode，再按平台取字段（原实现 body[SYSTEM] 必为 nil）
  local data = root[config.SYSTEM]
  if type(data) ~= "table" then
    return false, "[!] 配置表中不存在平台: " .. config.SYSTEM
  end

  local version = semver(data.version)
  if not version then return false, "[!] 远端版本号不合法" end

  if not (version > config.VERSION) then
    print("[*] 已经是最新版本")
    return true, nil
  end

  print("[*] 发现新版本\n")
  print("v" .. tostring(version))
  print(tostring(data.date) .. " 发布")
  print(tostring(data.description))
  print(tostring(data.size))
  print("是否更新? [yes/no]")

  if io.read("*l") ~= "yes" then
    print("[!] 退出更新")
    return false, nil
  end

  local dist_bin = config.DIST_DIR .. "\\yyfloat-" .. tostring(version)
  local dl_ok, derr = core.download(data.url, dist_bin)
  if not dl_ok then return false, derr end

  local yyfloat_link = core.which(config.SELF)
  if not yyfloat_link then
    return false, "[!] 未能在 PATH 中找到 " .. config.SELF .. "，无法切换版本"
  end

  -- 修正顺序：先备份旧版本，再切换软链接
  local b_ok, berr = core.backup(
    yyfloat_link,
    config.BACKUPS_DIR,
    {
      type = "old_version_backup",
      version = tostring(config.VERSION),
      time = os.date("!%Y-%m-%d %H-%M-%S"),
    })
  if not b_ok then
    print("[!] 备份旧版本失败(继续更新): " .. tostring(berr))
  else
    print("[*] 旧版本已备份: " .. tostring(berr))
  end

  local r_ok, rerr = core.retarget(dist_bin, yyfloat_link)
  if not r_ok then return false, rerr end

  print("[*] 更新完成，输入 yyfloat <command> 启动新版本")
  return true, nil
end

return M

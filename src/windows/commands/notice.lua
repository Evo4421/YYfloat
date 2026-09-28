#!/usr/bin/env lua

--- notice 命令：查看官方公告
-- @module commands.notice

local config = require "config"
local core = require "core"

local M = {}

--- 拉取并打印公告
-- @treturn boolean 是否成功
-- @treturn string|nil 错误说明
function M.run()
  local body, code, err = core.http_get(config.NOTICE_URL)
  if not body then return false, err end
  if code ~= 200 then
    return false, "[!] 无法正常请求公告 API: HTTP " .. tostring(code)
  end

  local ok, data = pcall(require("dkjson").decode, body)
  if not ok or type(data) ~= "table" then
    return false, "[!] 公告损坏"
  end

  if data.msg and data.msg ~= "" then
    print(data.msg)
  else
    print("[*] 暂无公告")
  end
  return true, nil
end

return M

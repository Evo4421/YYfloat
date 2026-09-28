#!/usr/bin/env lua

--- argparse 解析结果访问工具
-- @module commands.args_util

local M = {}

--- 判断某个子命令或开关是否被选中
-- @tparam table args 解析结果表
-- @tparam string name 命令/标志名
-- @tparam string|nil parent 父命令名（用于在嵌套结构中定位）
-- @treturn boolean 是否被选中
function M.selected(args, name, parent)
  if parent and type(args[parent]) == "table" then
    local v = args[parent][name]
    return v ~= nil and v ~= false
  end
  local v = args[name]
  if v == nil or v == false then return false end
  return true
end

--- 读取参数值（兼容扁平与嵌套两种结构）
-- @tparam table args 解析结果表
-- @tparam string name 参数名
-- @tparam string|nil parent 父命令名
-- @treturn any 参数值（不存在时为 nil；列表参数返回 table）
function M.value(args, name, parent)
  if parent and type(args[parent]) == "table" then
    local v = args[parent][name]
    if type(v) == "table" then return v end
    return v
  end
  return args[name]
end

--- 读取字符串型参数（自动兼容列表包装）
-- @tparam table args 解析结果表
-- @tparam string name 参数名
-- @tparam string|nil parent 父命令名
-- @treturn string|nil 参数值
function M.text(args, name, parent)
  local v = M.value(args, name, parent)
  if type(v) == "table" then return v[1] end
  if type(v) == "string" then return v end
  return nil
end

return M

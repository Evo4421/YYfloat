#!/usr/bin/env lua

--- YYfloat 主入口
-- 负责目录初始化、命令行参数解析与命令分发。
-- 各子命令实现位于 commands/ 目录
-- @script yyfloat

-- YYfloat v26.1.0
-- Copyright(c) Evo 2026, MIT Licensed

package.path = package.path .. ";./?.lua;./lib/?.lua;./lib/sub/?.lua;./lib/?.lua"

local lfs = require "lfs"
local argparse = require "argparse"

local config = require "config"
local core = require "core"
local args_util = require "commands.args_util"

--- 确保基础目录与文件存在
local function bootstrap()
  local dirs = { config.ROOT, config.DIST_DIR, config.BACKUPS_DIR, config.PLUGINS_DIR }
  for i = 1, #dirs do
    if lfs.attributes(dirs[i], "mode") ~= "directory" then
      lfs.mkdir(dirs[i])
    end
  end

  if lfs.attributes(config.VERSION_FILE, "mode") ~= "file" then
    local f = io.open(config.VERSION_FILE, "w")
    if f then f:write(tostring(config.VERSION)) f:close() end
  end

  if lfs.attributes(config.PLUGINS_LIST, "mode") ~= "file" then
    core.write_json(config.PLUGINS_LIST, {})
  end
end

--- 统一执行命令模块并处理结果
-- @tparam string module_name 命令模块名（commands/ 下）
-- @tparam table args 传给模块的参数表
local function dispatch(module_name, args)
  local ok, mod = pcall(require, "commands." .. module_name)
  if not ok then
    print("[!] 无法加载命令模块: " .. tostring(mod))
    os.exit(1)
  end
  local done, err = mod.run(args)
  if not done then
    if err then print(tostring(err)) end
    os.exit(1)
  end
end

bootstrap()

--- 参数定义
local parser = argparse("yyfloat",
  "简单来说，yyfloat 就是一个工具合集，用户可以在 yyfloat 的插件市场下载工具使用。" ..
  "yyfloat 插件市场包含了诸多功能强大的工具链，全部免费且开源。")

parser:flag("-v --version", "显示当前版本号")
  :action(function()
    print("YYfloat v" .. tostring(config.VERSION) ..
      "  Copyright(c) 2026 Evo, MIT Licensed\n" ..
      "输入 'yyfloat --help' 查看帮助信息\n" ..
      "该版本为预发布版本，不提供长期支持和维护。")
    os.exit(0)
  end)

local plugins = parser:command("plugins", "YYfloat 插件市场")

local plugins_install = plugins:command("install", "根据插件名字下载插件")
plugins_install:argument("plugin_name", "插件名称"):args(1)

local plugins_search = plugins:command("search", "根据插件名称、标签、关键词搜索插件")
plugins_search:argument("search_word", "搜索词"):args(1)

local plugins_update = plugins:command("update", "尝试更新指定的或所有的插件")
plugins_update:argument("plugin_name", "插件名称"):args("?")

local plugins_list = plugins:command("list", "列出本地所有插件")

local use = parser:command("use", "根据名称打开一个插件")
use:argument("plugin_name", "插件名称"):args(1)
use:argument("extra_args", "传递给插件的参数"):args("*")
use:flag("--doc", "查看插件文档")
use:flag("--version", "查看插件版本")
use:flag("--license", "查看插件许可证")
use:flag("--author", "查看插件作者")

parser:command("update", "更新 YYfloat 自身")
parser:command("notice", "查看官方发布的公告")

local check = parser:command("check", "快速检查插件状态")
check:argument("plugin_name", "插件名称"):args(1)

local remove = parser:command("remove", "删除一个插件")
remove:argument("plugin_name", "插件名称"):args(1)

local args = parser:parse()

--- 命令分发
-- 注意: argparse 0.7.x 将子命令与参数"扁平"存入结果表,
-- 因此这里传入整个 args, 由 args_util 兼容读取。
-- `plugins update` 与顶层 `update` 都会置 update=true, 以 args.plugins 区分。
if args.plugins then
  dispatch("plugins", args)
elseif args.update then
  dispatch("update", {})
end

if args.use then
  dispatch("use", args)
end

if args.notice then
  dispatch("notice", {})
end

if args.check then
  dispatch("check", args_util.text(args, "plugin_name"))
end

if args.remove then
  dispatch("remove", args_util.text(args, "plugin_name"))
end
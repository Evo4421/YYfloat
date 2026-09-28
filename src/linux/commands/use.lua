#!/usr/bin/env lua

--- use 命令：查看插件文档/版本/作者/许可证，或启动插件
-- @module commands.use

local config = require "config"
local core = require "core"
local plugin = require "plugin"
local args_util = require "commands.args_util"

local M = {}

--- 读取插件 manifest.json
-- @tparam string name 插件名
-- @treturn table|nil manifest 内容
-- @treturn string|nil 错误说明
local function load_manifest(name)
  return core.read_json(config.PLUGINS_DIR .. "/" .. name .. "/manifest.json")
end

--- use 命令入口
-- @tparam table au argparse 解析结果
-- @treturn boolean 是否成功
-- @treturn string|nil 错误说明
function M.run(au)
  local name = args_util.text(au, "plugin_name", "use")
  if not name then return false, "[!] 缺少插件名称" end
  if not core.validate_name(name) then return false, "[!] 非法的插件名称" end

  local plugin_dir = config.PLUGINS_DIR .. "/" .. name
  local manifest, merr = load_manifest(name)
  if not manifest then return false, "[!] 无法读取插件元数据: " .. tostring(merr) end

  -- 查看文档
  if args_util.selected(au, "doc", "use") then
    local cli_doc = manifest["cli-doc"]
    if not cli_doc then return false, "[!] 该插件未提供文档" end

    local f = io.open(plugin_dir .. "/" .. cli_doc, "r")
    if not f then return false, "[!] 无法打开文档: " .. tostring(cli_doc) end
    local text = f:read("*a")
    f:close()

    local lines = {}
    for line in text:gmatch("([^\n]*)\n?") do
      lines[#lines + 1] = line
    end

    local panel = require "terminal.ui.panel"
    local ok, err = pcall(function()
      local doc_panel = panel.text { lines = lines, max_lines = 30, auto_render = true }
      local screen = panel.screen {
        header = name .. " Document",
        body = doc_panel,
        footer = "按 [q] 退出",
      }
      screen:calculate_layout()
      screen:render()
    end)
    if not ok then return false, "[!] 渲染文档失败: " .. tostring(err) end
    return true, nil
  end

  -- 查看版本
  if args_util.selected(au, "version", "use") then
    print(name .. " v" .. tostring(manifest.version))
    return true, nil
  end

  -- 查看作者
  if args_util.selected(au, "author", "use") then
    print(tostring(manifest.author))
    return true, nil
  end

  -- 查看许可证
  if args_util.selected(au, "license", "use") then
    local lics = manifest.license
    if not lics then return false, "[!] 该插件未声明许可证" end
    local f = io.open(plugin_dir .. "/" .. lics, "r")
    if not f then return false, "[!] 无法打开许可证文件: " .. tostring(lics) end
    print(f:read("*a"))
    f:close()
    return true, nil
  end

  -- 启动插件
  local state = plugin.exist(name)
  if not state then return false, "[!] 不存在 " .. name .. " 这个插件" end
  if state == "occupied" then
    return false, "[!] 插件所处目录被异常占用，请尝试使用 yyfloat remove 彻底删除后重装"
  end
  if state == "damaged" then
    return false, "[!] 插件已损坏，请使用 yyfloat check 排查"
  end

  return plugin.open(name, args_util.value(au, "extra_args", "use"))
end

return M

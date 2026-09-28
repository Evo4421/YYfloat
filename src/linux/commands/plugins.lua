#!/usr/bin/env lua

--- 插件市场命令：install / search / update / list
-- @module commands.plugins

local semver = require "semver"

local config = require "config"
local core = require "core"
local plugin = require "plugin"
local args_util = require "commands.args_util"

local M = {}

--- 拉取远端插件表
-- @treturn table|nil 插件表
-- @treturn string|nil 错误说明
local function fetch_catalog()
  local body, code, err = core.http_get(config.PLUGINS_URL)
  if not body then return nil, err end
  if code ~= 200 then return nil, "[!] 拉取插件列表失败: HTTP " .. tostring(code) end
  local ok, decoded = pcall(require("cjson").decode, body)
  if not ok then return nil, "[!] 无法解析插件配置表" end
  return decoded, nil
end

--- 安全解压 zip 到插件目录
-- @tparam string zip_path 压缩包路径
-- @tparam string dest 解压目录
-- @treturn boolean 是否成功
-- @treturn string|nil 错误说明
local function safe_unzip(zip_path, dest)
  local cmd = string.format("unzip -o %s -d %s",
    core.shell_escape(zip_path), core.shell_escape(dest))
  local ok, _, code = os.execute(cmd)
  if not ok then
    return false, "[!] 解压失败, 退出码: " .. tostring(code)
  end
  return true, nil
end

--- 下载并安装插件包（含长度校验），返回是否成功
-- @tparam string name 插件名
-- @tparam string url 下载地址
-- @treturn boolean 是否成功
-- @treturn string|nil 错误说明
local function install_package(name, url)
  local plugin_file = config.PLUGINS_DIR .. "/" .. name .. ".zip"
  local ok, err = core.download(url, plugin_file)
  if not ok then return false, err end

  print("[*] 下载完成，正在解压...")
  local unzipped, uerr = safe_unzip(plugin_file, config.PLUGINS_DIR)
  os.remove(plugin_file)
  if not unzipped then return false, uerr end
  return true, nil
end

--- install 子命令
-- @tparam string plugin_name 插件名称
-- @treturn boolean 是否成功
-- @treturn string|nil 错误说明
function M.install(plugin_name)
  local state = plugin.exist(plugin_name)
  if state == "occupied" then return false, "[!] " .. plugin_name .. " 所处目录被占用" end
  if state == "damaged" then
    return false, "[!] " .. plugin_name .. " 存在但损坏，请使用 'yyfloat check " .. plugin_name .. "' 检查"
  end
  if state then return false, "[!] " .. plugin_name .. " 已经存在" end

  local catalog, cerr = fetch_catalog()
  if not catalog then return false, cerr end

  local data = catalog[plugin_name]
  if type(data) ~= "table" then
    return false, "[!] 没有找到 " .. plugin_name .. " 的有效版本"
  end

  print("[*] 找到 " .. plugin_name)
  print(plugin_name .. " v" .. tostring(data.version))
  print("作者: " .. tostring(data.author))
  print(tostring(data.description))
  print("大小: " .. tostring(data.size))
  print("是否下载？输入 [yes]/[no]")

  local confirm = io.read("*l")
  if confirm ~= "yes" then
    print("[*] 中途退出")
    return false, nil
  end

  local ok, err = install_package(plugin_name, data.url)
  if not ok then return false, err end

  -- 元数据写入（原子）
  local list = core.read_json(config.PLUGINS_LIST) or {}
  list[plugin_name] = {
    author = data.author,
    version = data.version,
    description = data.description,
    url = data.url,
    size = data.size,
  }
  local wrote, werr = core.write_json(config.PLUGINS_LIST, list)
  if not wrote then return false, werr end

  print("[*] 安装完成")
  return true, nil
end

--- search 子命令
-- @tparam string word 搜索词
-- @treturn boolean 是否成功
-- @treturn string|nil 错误说明
function M.search(word)
  local catalog, cerr = fetch_catalog()
  if not catalog then return false, cerr end

  local results = plugin.search(catalog, word)
  if #results == 0 then
    return false, "[!] 没有找到关于 " .. word .. " 的项"
  end

  print("[*] 一共找到 " .. #results .. " 项结果")
  for _, name in ipairs(results) do
    local project = catalog[name]
    print(name .. " v" .. tostring(project.version))
    print(tostring(project.author))
    print("最晚发布于 " .. tostring(project.date))
    print(tostring(project.description))
    -- 标签为数组, 需拼接展示（原实现 tostring(table) 会输出地址）
    local tags = project.tags
    if type(tags) == "table" then
      print("标签: " .. table.concat(tags, ", "))
    else
      print("标签: " .. tostring(tags))
    end
    print()
  end
  return true, nil
end

--- 更新单个插件
-- @tparam string plugin_name 插件名
-- @treturn boolean 是否成功
-- @treturn string|nil 错误说明
local function update_one(plugin_name)
  local state = plugin.exist(plugin_name)
  if not state then return false, "[!] 不存在这个插件的有效版本!" end
  if state == "occupied" then
    return false, "[!] 该插件被其他文件占用，请尝试通过 yyfloat remove 删除后重装"
  end
  if state == "damaged" then
    return false, "[!] 该插件损坏，请通过 yyfloat check 查看解决方案"
  end

  local catalog, cerr = fetch_catalog()
  if not catalog then return false, cerr end

  local data = catalog[plugin_name]
  if type(data) ~= "table" then return false, "[!] 无法找到关于此插件的有效版本!" end

  local list = core.read_json(config.PLUGINS_LIST) or {}
  local local_ver = list[plugin_name] and list[plugin_name].version or "0.0.0"
  local remote_ver = semver(data.version)
  if not remote_ver then return false, "[!] 该插件没有一个合法的版本!" end

  if semver(local_ver) >= remote_ver then
    print("[*] 已经是最新版本")
    return true, nil
  end

  print("[*] 发现新版本: " .. tostring(remote_ver))
  print("[*] 正在下载...")
  local ok, err = install_package(plugin_name, data.url)
  if not ok then return false, err end

  -- 从 manifest.json 读取真实元数据
  local manifest, merr = core.read_json(config.PLUGINS_DIR .. "/" .. plugin_name .. "/manifest.json")
  if not manifest then return false, "[!] 不存在或无法解析 manifest.json: " .. tostring(merr) end

  list[plugin_name] = {
    author = manifest.author or data.author,
    version = manifest.version or data.version,
    description = manifest.description or data.description,
    size = manifest.size or data.size,
  }
  local wrote, werr = core.write_json(config.PLUGINS_LIST, list)
  if not wrote then return false, werr end

  print("[*] 安装完成")
  return true, nil
end

--- 更新全部插件
-- @treturn boolean 是否成功
-- @treturn string|nil 错误说明
local function update_all()
  local list = core.read_json(config.PLUGINS_LIST) or {}
  print("[*] 正在遍历插件配置...")

  local catalog, cerr = fetch_catalog()
  if not catalog then return false, cerr end

  local comv = core.comparison("version", nil, list, catalog)
  if not comv then
    print("[*] 所有插件均是最新版本")
    return true, nil
  end

  local updated = 0
  for _, v in ipairs(comv) do
    local k = v.key
    local v1 = semver(v.values[1] or "0.0.0")
    local v2 = semver(v.values[2] or "0.0.0")

    if v2 and v1 and v2 > v1 then
      local data = catalog[k]
      -- 修正：按实际键取 url（原实现 data.k.url 永远取不到）
      if data and data.url then
        print("找到 " .. k .. " 新版本 " .. tostring(v2))
        local ok, err = install_package(k, data.url)
        if ok then
          list[k] = {
            author = data.author,
            description = data.description,
            version = data.version,
            size = data.size,
          }
          updated = updated + 1
          print("[*] " .. k .. " v" .. tostring(data.version) .. " 已准备好")
        else
          print(tostring(err))
        end
      end
    end
  end

  if updated > 0 then
    local wrote, werr = core.write_json(config.PLUGINS_LIST, list)
    if not wrote then return false, werr end
  end
  return true, nil
end

--- plugins 命令入口
-- @tparam table args argparse 解析结果（扁平或嵌套结构均可）
-- @treturn boolean 是否成功
-- @treturn string|nil 错误说明
function M.run(args)
  if args_util.selected(args, "install", "plugins") then
    return M.install(args_util.text(args, "plugin_name", "plugins"))
  end

  if args_util.selected(args, "search", "plugins") then
    return M.search(args_util.text(args, "search_word", "plugins"))
  end

  if args_util.selected(args, "update", "plugins") then
    local target = args_util.text(args, "plugin_name", "plugins")
    if target then
      return update_one(target)
    end
    return update_all()
  end

  if args_util.selected(args, "list", "plugins") then
    local list = core.read_json(config.PLUGINS_LIST) or {}
    for k, v in pairs(list) do
      if type(v) == "table" then
        print(k .. " v" .. tostring(v.version))
        print(tostring(v.author))
        print(tostring(v.description))
        print(tostring(v.size))
        print("\n")
      end
    end
    return true, nil
  end

  return true, nil
end

return M

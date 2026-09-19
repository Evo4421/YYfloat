-- !/usr/bin/env lua

--[=[
  YYfloat v26.1.0
  Copyright(c) Evo 2026, MIT Licensed
]=]

package.path = package.path .. ";./?.lua;./lib/?.lua;./lib/sub/?.lua"

local lfs = require "lfs"
local argparse = require "argparse"
local https = require "ssl.https"
local cjson = require "cjson"
local semver = require "semver"
local md5 = require "md5"

local config = require "config"
local core = require "core"
local plugin = require "plugin"

if lfs.attributes(config.ROOT, "mode") ~= "directory" then lfs.mkdir(config.ROOT) end
if lfs.attributes(config.DIST_DIR, "mode") ~= "directory" then lfs.mkdir(config.DIST_DIR) end
if lfs.attributes(config.BACKUPS_DIR, "mode") ~= "directory" then lfs.mkdir(config.BACKUPS_DIR) end
if lfs.attributes(config.PLUGINS_DIR, "mode") ~= "directory" then lfs.mkdir(config.PLUGINS_DIR) end
if lfs.attributes(config.VERSION_FILE, "mode") ~= "file" then 
  local verfile = io.open(config.VERSION_FILE, "w")
  verfile:write(tostring(config.VERSION))
  verfile:close()
end
if lfs.attributes(config.PLUGINS_LIST, "mode") ~= "file" then
  local list_file = io.open(config.VERSION_FILE, "w")
  list_file:write("{}")
  last_file:close()
end

local parser = argparse("yyfloat", "简单来说，yyfloat就是一个工具合集，用户可以在yyfloat的插件市场下载工具使用。yyfloat插件市场包含了诸多功能强大的工具链,全部免费且开源。")
parser:flag("-v --version", "显示当前版本号")
  :action(function()
    print("YYfloat v" .. tostring(config.VERSION) .. "  Copyright(c) 2026 Evo, MIT Licensed\n输入'yyfloat --help'查看帮助信息\n该版本为预发布版本,不提供长期支持和维护。")
    os.exit(0)
  end)

local plugins = parser:command("plugins", "YYfloat插件市场")

local plugins_install = plugins:command("install", "根据插件名字下载插件")
plugins_install:argument("plugin_name", "插件名称"):args(1)

local plugins_search = plugins:command("search", "根据插件名称，标签，关键词搜索插件")
plugins_search:argument("search_word", "搜索词"):args(1)

local plugins_update = plugins:command("update", "尝试更新指定的或所有的插件")
plugins_update:argument("plugin_name", "插件名称"):args("?")

local plugins_list = plugins:command("list", "列出所有插件")

local use = parser:command("use", "根据名称打开一个插件")
use:argument("plugin_name", "插件名称"):args(1)
use:argument("extra_args", "传递给插件的参数"):args("*")
use:flag("--doc", "查看插件文档")
use:flag("--version", "查看插件版本")
use:flag("--license", "查看插件许可证")
use:flag("--author", "查看插件作者")

local update = parser:command("update", "更新YYfloat")
local notice = parser:command("notice", "查看官方发布的公告")

local check = parser:command("check", "快速检查插件状态")
check:argument("plugin_name", "插件名称").args(1)

local args = parser:parse()

if args.plugins then
  local p = args.plugins
  
  if p.install then
    local plugin_name = p.install.plugin_name
    
    local plugin_exist = plugin.exist(plugin_name)
    if plugin_exist == "occupied" then error("[!] " .. plugin_name .. "所处目录被占用") end
    if plugin_exist == "damaged" then error("[!] " .. plugin_name .. "存在已但损坏，请使用'yyfloat check " .. plugin_name .. "'检查具体情况") end  
    if plugin_exist then 
      print("[*] " .. plugin_name .. "已经存在")
      os.exit(1)
    end
    
    local body, code, headers = https.request(config.PLUGINS_URL)
    if code == 200 then
      local plugins_data = assert(cjson.decode(body), "[!] 无法解析插件配置表!")
      
      if plugins_data.plugin_name then
        local data = plugins_data.plugin_name
        
        local version = data.version
        local author = data.author
        local description = data.description
        local size = data.size
        local url = data.url
        
        print("[*] 找到" .. plugin_name)
        print(plugin_name .. "v" .. version)
        print("作者: " .. author)
        print(description)
        print("大小: " .. size)
        print("是否下载？输入[yes]/[no]")
        local confirm = assert(tostring(io.read("*l")), "[!] 输入不合法!")
        
        if confirm == "yes" then
          local plugin_file = config.PLUGINS_DIR .. "/" .. plugin_name .. ".zip"
          core.download(url, plugin_file)
          print("[*] 下载完成，正在解压...")
          
          os.execute('unzip -o "' .. plugin_file .. '" -d "' .. config.PLUGINS_DIR .. '"')
          os.remove(plugin_file)
          
          core.json_append(
            config.PLUGINS_LIST,
            {
              plugin_name = {
                author = author,
                version = version,
                position = config.PLUGINS_DIR .. "/" .. plugin_name,
                size = size
              },
            }
          )
          print("[*] 安装完成")
        else
          print("[*] 中途退出")
          os.exit(1)
        end
      else
        print("[!] 没有找到" .. plugin_name .. "的有效版本")
        os.exit(1)
      end
    else
      error("[!] 尝试拉取插件列表，但是响应失败了: " .. code)
    end
  end
  
  if p.search then
    local word = p.search.search_word
    
    local body, code, headers = https.request(config.PLUGINS_URL)
    if code == 200 then
      local data = cjson.decode(body)
      
      local search_result = plugin.search(data, word)
      
      if #search_result == 0 then
        print("[!] 没有找到关于" .. word .. "的项")
        os.exit(1)
      end
      
      print("[*] 一共找到" .. #search_result "项结果")
      for name in ipairs(search_result) do
        local project = data.name
        
        print(name .. "v" .. project.version)
        print(project.author)
        print("最晚发布于 " .. project.date)
        print(project.description)
        print("标签: " .. project.tags)
        print()
      end
    else
      error("[!] 尝试拉取插件列表，但是请求失败了: " .. code)
    end
  end

  if p.update then
    if p.update.plugin_name then
      local plugin_name = p.update.plugin_name
      if not plugin.exist(plugin_name) then 
        print("[!] 不存在这个插件的有效版本!")
        os.exit(1)
      elseif plugin.exist(plugin_name) == "occupied" then
        print("[!] 该插件被其他文件占用，请尝试通过yyfloat remove删除插件后重装")
        os.exit(1)
      elseif plugin.exist(plugin_name) == "damaged" then
        print("[!] 该插件损坏，请通过yyfloat check查看解决方案")
      end
    
      local body, code, headers = https.request(config.PLUGINS_URL)
      
      if code == 200 then
        local plugin_data = assert(cjson.decode(body), "[!] 无法解析插件配置表!")
        
        if plugin_data.plugin_name then
          local data = plugin_data.plugin_name
          local url = data.url
          
          local list_file = io.open(config.PLUGINS_LIST, "r")
          local list = cjson.decode(list_file:read("*a"))
          list_file:close()
          
          local version = assert(semver(data.version), "[!] 该插件没有一个合法的版本!")
          if semver(list.plugin_name.version) < version then
            print("[*] 发现新版本: " .. version)
            print("[*] 正在下载...")
            
            local plugin_file = config.PLUGINS_DIR .. "/" .. plugin_name .. ".zip"
            core.download(url, plugin_file)
            
            print("[*] 下载完成，正在安装...")
            os.execute('unzip -o "' .. plugin_file .. '" -d "' .. config.PLUGINS_DIR .. '"')
            os.remove(plugin_file)
            
            local manifest = assert(io.open(config.PLUGINS_DIR .. "/" .. plugin_name .. "/manifest.json", "r"), "[!] 不存在manifest.json")
            local manifest_data = cjson.decode(manifest:read())
            manifest:close()
            
            local author = manifest_data.author
            local version = manifest_data.version
            
            list.plugin_name.author = author
            list.plugin_name.version = version
            
            local write_list = io.open(config.PLUGINS_LIST, "w")
            write_list:write(cjson.encode(list))
            write_list:close()
            
            print("[*] 安装完成")
          end
        end
      end
    end
  end
end
#!/usr/bin/env lua

--- YYfloat 底层工具模块
-- 提供文件复制、HTTP请求、JSON读写、路径校验等基础能力
-- @module core

local cjson = require "dkjson"

local Exports = {}

--- @section 文件系统操作

--- 判断文件是否存在
-- @tparam string path 文件路径
-- @treturn boolean
function Exports.file_exists(path)
  local f = io.open(path, "r")
  if f then f:close() return true end
  return false
end

--- 判断目录是否存在
-- @tparam string path 目录路径
-- @treturn boolean
function Exports.is_dir(path)
  local h = io.popen('dir /ad /b "' .. path .. '" 2>nul')
  if not h then return false end
  local ok = h:close()
  return ok == true or ok == 0
end

--- 递归创建目录
-- @tparam string path 目录路径
-- @treturn boolean
function Exports.mkdir_p(path)
  local ok = os.execute('md "' .. path .. '" 2>nul')
  return ok == true or ok == 0
end

--- @section 文件操作

--- 重命名
local function fs_rename(from, to)
  local ok, err = os.rename(from, to)
  if ok == nil or ok == false then return false, err or "rename 失败" end
  return true, nil
end

--- 删除文件
local function fs_unlink(path)
  local ok = os.remove(path)
  return ok ~= nil and ok ~= false
end

--- 替换可执行文件指向
-- 用 copy 覆盖旧文件
local function fs_replace(target, linkpath)
  local cmd = 'copy /y "' .. target .. '" "' .. linkpath .. '" >nul'
  local ok = os.execute(cmd)
  if not ok then return false, "copy 失败" end
  return true, nil
end

--- 获取 PID
local function fs_getpid()
  return 0
end

--- 生成随机后缀
local function temp_name(prefix)
  return string.format("%s.tmp_%d_%d", prefix, fs_getpid(), math.random(100000, 999999))
end

--- @section 校验与转义

--- 校验插件名称
function Exports.validate_name(name)
  if type(name) ~= "string" or name == "" then return false end
  if not name:match("^[%w_%-%.]+$") then return false end
  if name:find("%.%.") or name:sub(1, 1) == "." then return false end
  return true
end

--- Shell 转义
-- 用双引号包裹，内部双引号转义
function Exports.shell_escape(s)
  s = tostring(s or "")
  return '"' .. s:gsub('"', '""') .. '"'
end

--- @section JSON 读写

--- 读取并解析 JSON 文件
function Exports.read_json(path)
  local f, oerr = io.open(path, "r")
  if not f then return nil, "[!] 无法打开文件: " .. tostring(oerr) end
  local content = f:read("*a")
  f:close()
  if not content or content == "" then return {}, nil end
  local ok, data = pcall(cjson.decode, content)
  if not ok then return nil, "[!] JSON 解析失败: " .. tostring(data) end
  return data, nil
end

--- 原子写入 JSON 文件
function Exports.write_json(path, data)
  local ok, encoded = pcall(cjson.encode, data)
  if not ok then return false, "[!] JSON 序列化失败: " .. tostring(encoded) end
  local tmp = temp_name(path)
  local f, oerr = io.open(tmp, "w")
  if not f then return false, "[!] 无法写入: " .. tostring(oerr) end
  f:write(encoded)
  f:close()
  local renamed, rerr = fs_rename(tmp, path)
  if not renamed then
    fs_unlink(tmp)
    return false, "[!] 落盘失败: " .. tostring(rerr)
  end
  return true, nil
end

--- @section 文件复制与备份

--- 流式复制二进制文件
function Exports.copy(file, target)
  local fin, oerr = io.open(file, "rb")
  if not fin then return false, "[!] 无法读取源文件: " .. tostring(oerr) end
  local temp = temp_name(target)
  local fout, werr = io.open(temp, "wb")
  if not fout then
    fin:close()
    return false, "[!] 无法写入目标: " .. tostring(werr)
  end
  local ok, err = true, nil
  while true do
    local chunk = fin:read(4096)
    if not chunk then break end
    ok, err = fout:write(chunk)
    if not ok then break end
  end
  fin:close()
  fout:close()
  if not ok then
    fs_unlink(temp)
    return false, "[!] 写入失败: " .. tostring(err)
  end
  local renamed, rerr = fs_rename(temp, target)
  if not renamed then
    fs_unlink(temp)
    return false, "[!] 无法替换目标文件: " .. tostring(rerr)
  end
  return true, nil
end

--- 替换可执行文件
function Exports.retarget(target, linkpath)
  return fs_replace(target, linkpath)
end

--- 查找命令路径
-- PATH 用分号分隔，自动尝试 .exe/.bat/.cmd 后缀
function Exports.which(cmd)
  if not Exports.validate_name(cmd) then return nil end
  local path = os.getenv("PATH") or "C:\\Windows\\System32;C:\\Windows"
  for dir in path:gmatch("[^;]+") do
    for _, ext in ipairs({ "", ".exe", ".bat", ".cmd" }) do
      local full = dir .. "\\" .. cmd .. ext
      if Exports.file_exists(full) then
        return full
      end
    end
  end
  return nil
end

--- 获取文件 SHA256
-- 用 certutil 命令
function Exports.sha256(path)
  local h = io.popen('certutil -hashfile "' .. path .. '" SHA256 2>nul')
  if not h then return nil end
  local out = h:read("*a") or ""
  h:close()
  -- certutil 输出第二行是 hash
  local hex = out:match("\n(%x+)\n")
  if hex then hex = hex:gsub("%s", "") end
  return hex
end

--- 备份文件
function Exports.backup(file, target, metadata)
  local base = file:match("([^\\]+)$") or "backup"
  local stamp = os.date("!%Y%m%d-%H%M%S")
  local backup_dir = string.format("%s\\%s-backup-%s", target, base, stamp)
  if not Exports.mkdir_p(backup_dir) then
    return false, "[!] 备份目录创建失败"
  end
  local copied, cerr = Exports.copy(file, backup_dir .. "\\" .. base)
  if not copied then return false, cerr end
  local wrote, werr = Exports.write_json(backup_dir .. "\\metadata.json", metadata)
  if not wrote then return false, werr end
  return true, backup_dir
end

--- @section HTTP 请求

--- HTTP GET 请求
-- 用 curl 命令
function Exports.http_get(url, opts)
  opts = opts or {}
  local to = tostring(opts.timeout or 20)
  local cmd = "curl -sS --connect-timeout " .. to .. " -m " .. to
  if opts.cafile and Exports.file_exists(opts.cafile) then
    cmd = cmd .. " --cacert " .. Exports.shell_escape(opts.cafile)
  elseif opts.verify == "none" then
    cmd = cmd .. " -k"
  end
  cmd = cmd .. ' -w "\\n%{http_code}" ' .. Exports.shell_escape(url)
  local handle = io.popen(cmd .. " 2>nul")
  if not handle then return nil, nil, "[!] curl 执行失败" end
  local output = handle:read("*a") or ""
  handle:close()
  local body, code = output:match("^(.*)\n(%d+)%s*$")
  if not body then
    body, code = output, 200
  end
  if code == "000" then
    return nil, nil, "[!] 网络请求失败"
  end
  return body, tonumber(code) or 200, nil
end

--- 下载文件
-- 用 curl -o
function Exports.download(url, target)
  local cmd = "curl -sS -L --connect-timeout 20 -m 600"
  cmd = cmd .. " -o " .. Exports.shell_escape(target) .. " " .. Exports.shell_escape(url)
  local ok, _, code = os.execute(cmd .. " 2>nul")
  if not ok then
    os.remove(target)
    return false, "[!] 下载失败: curl 退出码 " .. tostring(code)
  end
  local f = io.open(target, "rb")
  if not f then return false, "[!] 下载文件不可读" end
  local size = f:seek("end")
  f:close()
  if size == 0 then
    os.remove(target)
    return false, "[!] 下载文件为空"
  end
  print("[*] 下载完成 (" .. tostring(size) .. " 字节)")
  return true, nil
end

--- @section JSON 数组追加

--- 向 JSON 数组追加记录
function Exports.json_append(file, content)
  local data, err = Exports.read_json(file)
  if not data then return false, err end
  if type(data) ~= "table" then return false, "[!] 目标不是 JSON 数组" end
  data[#data + 1] = content
  return Exports.write_json(file, data)
end

--- @section 多表比较

--- 多表字段比较
function Exports.comparison(field, comparator, ...)
  local n = select("#", ...)
  comparator = comparator or function(a, b) return a == b end
  local slots, key_order = {}, {}
  for i = 1, n do
    local t = select(i, ...)
    if type(t) == "table" then
      for k, entry in pairs(t) do
        local v = type(entry) == "table" and entry[field] or nil
        local s = slots[k]
        if not s then
          s = { first = nil, all_same = true, values = {}, missing_at = {} }
          slots[k] = s
          key_order[#key_order + 1] = k
        end
        s.values[i] = v
        if v == nil then
          s.missing_at[#s.missing_at + 1] = i
        elseif s.first == nil then
          s.first = v
        elseif s.all_same and not comparator(v, s.first) then
          s.all_same = false
        end
      end
    end
  end
  local diffs = {}
  for idx = 1, #key_order do
    local k = key_order[idx]
    local s = slots[k]
    if s.first ~= nil and (not s.all_same or #s.missing_at > 0) then
      diffs[#diffs + 1] = {
        key = k, field = field, values = s.values,
        missing_at = #s.missing_at > 0 and s.missing_at or nil,
      }
    end
  end
  if #diffs == 0 then return nil end
  return diffs
end

return Exports

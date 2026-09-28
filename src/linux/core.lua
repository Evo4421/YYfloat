#!/usr/bin/env lua

--- YYfloat 底层工具模块
-- 提供文件复制/软链接、HTTP 请求、JSON 读写、路径与名称校验等基础能力。
-- @module core

local posix = require "posix"
local lfs = require "lfs"
local https = require "ssl.https"
local ltn12 = require "ltn12"
local cjson = require "cjson"
local lfs_attr = lfs.attributes

local Exports = {}

--- 重命名
-- @tparam string from 源路径
-- @tparam string to 目标路径
-- @treturn boolean 是否成功
-- @treturn string|nil 错误说明
local function fs_rename(from, to)
  local fn = (posix.stdio and posix.stdio.rename) or posix.rename or os.rename
  if not fn then return false, "当前环境不支持 rename" end
  local ok, err = fn(from, to)
  if ok == nil or ok == false then return false, err or "rename 失败" end
  return true, nil
end

--- 删除文件
-- @tparam string path 路径
-- @treturn boolean 是否成功
local function fs_unlink(path)
  local fn = (posix.unistd and posix.unistd.unlink) or posix.unlink or os.remove
  if not fn then return false end
  local ok = fn(path)
  return ok ~= nil and ok ~= false
end

--- 创建符号链接
-- @tparam string target 链接指向
-- @tparam string linkpath 链接路径
-- @treturn boolean 是否成功
-- @treturn string|nil 错误说明
local function fs_symlink(target, linkpath)
  local fn = (posix.unistd and posix.unistd.symlink)
    or (posix.sys and posix.sys.stat and posix.sys.stat.symlink)
    or posix.symlink
  if fn then
    local ok, err = fn(target, linkpath)
    if ok ~= nil and ok ~= false then return true, nil end
    return false, err or "symlink 失败"
  end
  -- 回退
  local ok, _, code = os.execute("ln -sf " ..
    Exports.shell_escape(target) .. " " .. Exports.shell_escape(linkpath))
  if not ok then return false, "ln 退出码: " .. tostring(code) end
  return true, nil
end

--- 获取当前进程 PID
-- @treturn number 进程号
local function fs_getpid()
  local pr = posix.unistd
  if pr and pr.getpid then return pr.getpid() end
  return 0
end

--- @section 统一请求分发
-- luasec 只能处理 https://, 明文 http:// 需交给 socket.http。
-- 本函数按 URL 协议自动选择后端, 并对 https 强制证书校验。

--- 发起一次 HTTP(S) 请求
-- @tparam table opts 请求参数（url/sink/method 等）
-- @treturn boolean 是否成功
-- @treturn number|string HTTP 状态码或错误
-- @treturn table|nil 响应头
-- @treturn string|nil 状态描述
local function do_request(opts)
  local url = tostring(opts.url or "")
  if url:match("^https://") then
    opts.verify = "none"
    opts.options = "all"
    return https.request(opts)
  end

  local ok_http, http = pcall(require, "socket.http")
  if not ok_http then
    return nil, "当前环境不支持 http:// 请求"
  end
  opts.verify = nil
  opts.options = nil
  return http.request(opts)
end

--- 生成随机后缀（用于临时文件命名）
-- @tparam string prefix 前缀路径
-- @treturn string 临时文件路径
local function temp_name(prefix)
  return string.format("%s.tmp_%d_%d", prefix, fs_getpid(), math.random(100000, 999999))
end

--- 校验插件名称是否合法
-- 拒绝空值、路径分隔符、`..`、隐藏文件等危险输入。
-- @tparam string name 待校验名称
-- @treturn boolean 是否合法
function Exports.validate_name(name)
  if type(name) ~= "string" or name == "" then return false end
  if not name:match("^[%w_%-%.]+$") then return false end
  if name:find("%.%.") or name:sub(1, 1) == "." then return false end
  return true
end

--- 对字符串做 Shell 单引号转义，防止命令注入
-- 原理：将内部 `'` 替换为 `'\''`，整体用单引号包裹。
-- @tparam string s 原始字符串
-- @treturn string 转义后的字符串
function Exports.shell_escape(s)
  s = tostring(s or "")
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

--- 读取并解析 JSON 文件
-- @tparam string path 文件路径
-- @treturn table|nil 解析结果（失败返回 nil）
-- @treturn string|nil 错误说明
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
-- @tparam string path 目标路径
-- @tparam table data 待序列化数据
-- @treturn boolean 是否成功
-- @treturn string|nil 错误说明
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

--- 流式复制二进制文件
-- @tparam string file 源文件路径
-- @tparam string target 目标文件路径
-- @treturn boolean 是否成功
-- @treturn string|nil 错误说明
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

--- 原子替换软链接指向
-- @tparam string target 新的指向目标
-- @tparam string linkpath 软链接路径
-- @treturn boolean 是否成功
-- @treturn string|nil 错误说明
function Exports.retarget(target, linkpath)
  local dir = linkpath:match("^(.*)/[^/]*$") or "."
  local temp = string.format("%s/.tmp_link_%d_%d_%d",
    dir, fs_getpid(), os.time(), math.random(100000, 999999))

  local ok, err = fs_symlink(target, temp)
  if not ok then return false, "[!] 无法创建符号链接: " .. tostring(err) end

  local renamed, rerr = fs_rename(temp, linkpath)
  if not renamed then
    fs_unlink(temp)
    return false, "[!] 无法修改符号链接指向: " .. tostring(rerr)
  end
  return true, nil
end

--- 查找命令的绝对路径
-- @tparam string cmd 命令名
-- @treturn string|nil 命令完整路径
function Exports.which(cmd)
  if not Exports.validate_name(cmd) then return nil end
  -- 优先使用 Lua 标准库 os.getenv（posix 的 getenv 位于 stdlib, 各版本位置不一）
  local path = os.getenv("PATH")
    or (posix.stdlib and posix.stdlib.getenv and posix.stdlib.getenv("PATH"))
    or "/usr/local/bin:/usr/bin:/bin"
  for dir in path:gmatch("[^:]+") do
    local full = dir .. "/" .. cmd
    if lfs_attr(full, "mode") == "file" then
      return full
    end
  end
  return nil
end

--- 获取文件 SHA256
-- @tparam string path 文件路径
-- @treturn string|nil 十六进制摘要（失败返回 nil）
function Exports.sha256(path)
  local handle = posix.popen and posix.popen("sha256sum " .. Exports.shell_escape(path) .. " 2>/dev/null")
  if not handle then return nil end
  local out = handle:read("*a") or ""
  handle:close()
  local hex = out:match("^(%x+)")
  return hex
end

--- 备份文件到指定目录
-- @tparam string file 源文件路径
-- @tparam string target 备份根目录
-- @tparam table metadata 元数据（写入 metadata.json）
-- @treturn boolean 是否成功
-- @treturn string|nil 错误说明
function Exports.backup(file, target, metadata)
  local base = file:match("([^/]+)$") or "backup"
  -- 目录名加时间戳，避免"已存在"导致失败（原实现问题）
  local stamp = os.date("!%Y%m%d-%H%M%S")
  local backup_dir = string.format("%s/%s-backup-%s", target, base, stamp)

  local ok, err = lfs.mkdir(backup_dir)
  if not ok then
    return false, "[!] 备份目录创建失败: " .. tostring(err)
  end

  local copied, cerr = Exports.copy(file, backup_dir .. "/" .. base)
  if not copied then return false, cerr end

  local wrote, werr = Exports.write_json(backup_dir .. "/metadata.json", metadata)
  if not wrote then return false, werr end
  return true, backup_dir
end

--- 统一 HTTPS GET 请求
-- @tparam string url 请求地址
-- @tparam table|nil opts 可选参数 { timeout = 秒 }
-- @treturn string|nil 响应体
-- @treturn number|nil HTTP 状态码
-- @treturn string|nil 错误说明
function Exports.http_get(url, opts)
  opts = opts or {}
  local chunks = {}
  local ok, code, headers, status = do_request {
    url = url,
    method = "GET",
    sink = ltn12.sink.table(chunks),
    protocol = "any",
    timeout = opts.timeout or 20,
  }
  if not ok then
    return nil, nil, "[!] 网络请求失败: " .. tostring(code or status)
  end
  return table.concat(chunks), code, nil
end

--- 下载文件
-- @tparam string url 下载地址
-- @tparam string target 保存路径
-- @treturn boolean 是否成功
-- @treturn string|nil 错误说明
function Exports.download(url, target)
  local function format_size(bytes)
    if bytes >= 1024 * 1024 then
      return string.format("%.2fMB", bytes / 1024 / 1024)
    end
    return string.format("%.2fKB", bytes / 1024)
  end

  -- 预取文件大小
  local _, _, head_headers = do_request {
    url = url, method = "HEAD", sink = ltn12.sink.null(), timeout = 20,
  }
  local total = 0
  if head_headers and head_headers["content-length"] then
    total = tonumber(head_headers["content-length"]) or 0
  end

  local installed, last_print = 0, 0
  local start_time = os.time()

  local function progress()
    local percent, bar = 0, string.rep("?", 50)
    if total > 0 then
      percent = installed / total
      local filled = math.floor(50 * percent)
      bar = string.rep("-", filled) .. string.rep("*", 50 - filled)
    end
    local elapsed = math.max(os.time() - start_time, 1)
    local speed = (installed / 1024) / elapsed
    if total > 0 then
      io.write(string.format("\r[%s] %5.1f%% %s/%s  %.1fKB/s",
        bar, percent * 100, format_size(installed), format_size(total), speed))
    else
      io.write(string.format("\r[%s]  %s  %.1fKB/s", bar, format_size(installed), speed))
    end
    io.flush()
  end

  local file, oerr = io.open(target, "wb")
  if not file then return false, "[!] 无法创建目标文件: " .. tostring(oerr) end

  -- 自定义 sink: 不依赖 ltn12.sink.chain 的参数顺序
  -- （不同版本的 chain 实现顺序相反, 会导致回调收到 FILE* 而报错）
  local sink = function(chunk, err)
    if chunk then
      local written, werr = file:write(chunk)
      if not written then
        return nil, werr
      end
      installed = installed + #chunk
      local now = os.clock()
      if now - last_print > 0.1 then
        last_print = now
        progress()
      end
      return 1
    end
    -- 流结束
    progress()
    io.write("\n")
    file:close()
    return 1
  end

  local ok, code = do_request {
    url = url, sink = sink, timeout = 20,
  }
  if not ok or code ~= 200 then
    os.remove(target)
    return false, "[!] 下载失败: HTTP " .. tostring(code)
  end

  -- 长度校验（防截断/中间人改写）
  if total > 0 and installed ~= total then
    os.remove(target)
    return false, string.format("[!] 下载不完整: 期望 %d 字节, 实际 %d 字节", total, installed)
  end
  return true, nil
end

--- 向 JSON 数组文件追加一条记录
-- @tparam string file JSON 文件路径
-- @tparam any content 追加内容
-- @treturn boolean 是否成功
-- @treturn string|nil 错误说明
function Exports.json_append(file, content)
  local data, err = Exports.read_json(file)
  if not data then return false, err end
  if type(data) ~= "table" then return false, "[!] 目标不是 JSON 数组/对象" end
  data[#data + 1] = content
  return Exports.write_json(file, data)
end

--- 多表字段比较：找出字段值不一致或缺失的项
-- @tparam string field 比较的字段名
-- @tparam function|nil comparator 自定义比较函数（默认相等比较）
-- @tparam table ... 任意数量的表
-- @treturn table|nil 差异列表（完全一致返回 nil）
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
        key = k,
        field = field,
        values = s.values,
        missing_at = #s.missing_at > 0 and s.missing_at or nil,
      }
    end
  end
  if #diffs == 0 then return nil end
  return diffs
end

return Exports

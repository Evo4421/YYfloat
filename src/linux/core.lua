local posix = require "posix"
local lfs = require "lfs"
local https = require "ssl.https"
local cjson = require "cjson"

local Exports = {}

function Exports.copy(file, target)
  -- 复制二进制文件
  local fin = assert(io.open(file, "rb"), "[!] 无法读取源文件")

  local temp = string.format("%s.tmp_%d_%d", target, posix.unistd.getpid(), math.random(100000, 999999))
  local fout = assert(io.open(temp, "wb"), "[!] 无法写入")

  local ok, err
  while true do
    local chunk = fin:read(4096)
    if not chunk then break end
    ok, err = fout:write(chunk)
    if not ok then break end
  end

  fin:close()
  fout:close()

  if not ok then
    posix.unistd.unlink(temp)
    error("[!] 尝试写入失败: " .. tostring(err))
  end

  local renamed, rerr = posix.unistd.rename(temp, target)
  if not renamed then
    posix.unistd.unlink(temp)
    error("[!] 无法替换目标文件: " .. tostring(rerr))
  end
end

function Exports.retarget(target, linkpath)
  -- 替换软链接指向
  local dir = linkpath:match("^(.*)/[^/]*$") or "."
  local temp = string.format("%s/.tmp_link_%d_%d_%d", dir, posix.unistd.getpid(), os.time(), math.random(100000, 999999))

  local temp_link, err = posix.unistd.symlink(target, temp)
  if not temp_link then
    error("[!] 无法创建软链接: " .. tostring(err))
  end

  local symlink_ok, fail = posix.unistd.rename(temp, linkpath)
  if not symlink_ok then
    posix.unistd.unlink(temp)
    error("[!] 无法修改软链接指向.: " .. tostring(fail))
  end
end

function Exports.backup(file, target, metadata)
  -- 备份文件到指定路径
  local backup_dir = target .. "/" .. file .. "-backup"
  local ok, err = lfs.mkdir(backup_dir)
  if not ok then
    error("[!] 备份目录无法被创建或已存在")
  end
  
  Exports.copy(file, backup_dir .. "/" .. file)
  
  local metafile = assert(io.open(backup_dir .. "/metadata.json", "w"), "[!] 无法写入配置数据")
  metafile:write(metadata)
  metafile:close()
end

function Exports.download(url, target)
  -- 下载文件
  local function format_size(bytes)
    if bytes >= 1024 * 1024 then
      return string.format("%.2fMB", bytes / 1024 / 1024)
    else
      return string.format("%.2fKB", bytes / 1024)
    end
  end

  -- 先向目标发送一次HEAD请求，拿到headers
  local _, _, head_headers = https.request{
    url = url,
    method = "HEAD",
    sink = ltn12.sink.null(),
    timeout = 20,
  }
  local total = 0
  if head_headers and head_headers["content-length"] then
    total = tonumber(head_headers["content-length"]) or 0
  end

  local installed = 0
  local start_time = os.time()
  local last_print = 0

  local file = io.open(target, "wb")

  local function progress()
    local percent, bar

    if total > 0 then
      percent = installed / total
      local width = 50
      local filled = math.floor(width * percent)
      bar = string.rep("-", filled) .. string.rep("*", width - filled)
    else
      percent = 0
      bar = string.rep("?", 50)
    end

    local elapsed = os.time() - start_time
    if elapsed < 1 then elapsed = 1 end
    local speed = (installed / 1024) / elapsed

    local line
    if total > 0 then
      line = string.format(
        "\r[%s] %5.1f%% %s/%s  %.1fKB/s",
        bar,
        percent * 100,
        format_size(installed),
        format_size(total),
        speed
      )
    else
      line = string.format(
        "\r[%s]  %s  %.1fKB/s",
        bar,
        format_size(installed),
        speed
      )
    end

    io.write(line)
    io.flush()
  end

  local sink = ltn12.sink.chain(
    ltn12.sink.file(file),
    function(chunk)
      if chunk then
        installed = installed + #chunk
        local now = os.clock()

        if now - last_print > 0.1 then
          last_print = now
          progress()
        end
      else
        progress()
        io.write("\n")
      end
      return chunk
    end
  )

  local result, code, headers = https.request{
    url = url,
    sink = sink,
    timeout = 20
  }

  if code == 200 then
    print("[*] 下载完成!")
  else
    print("[!] 下载出错了: " .. tostring(code))
    os.remove(target)
  end
end

function Exports.json_append(file, content)
  local json_file = io.open(file, "r")
  local json = cjson.decode(json_file:read("*a"))
  json_file:close()
  
  table.insert(json, content)
  
  local new_json = io.open(file, "w")
  new_json:write(cjson.encode(json))
  new_json:close()
end
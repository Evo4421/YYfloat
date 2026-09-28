#!/usr/bin/env lua

--- YYfloat 全局配置模块
-- 集中定义路径、常量与远端地址
-- @module config

local semver = require "semver"

local Config = {}

--- 当前版本号
Config.VERSION = semver("26.1.0-alpha")

--- 用户主目录
Config.HOME = os.getenv("HOME") or os.getenv("USERPROFILE") or "C:\\Users\\Public"

--- 数据根目录
Config.ROOT = Config.HOME .. "\\.yyfloat"

--- 分发二进制目录
Config.DIST_DIR = Config.ROOT .. "\\dist"

--- 备份目录
Config.BACKUPS_DIR = Config.ROOT .. "\\backups"

--- 插件目录
Config.PLUGINS_DIR = Config.ROOT .. "\\extensions"

--- 可执行文件名
Config.SELF = "yyfloat"

--- 当前平台标识
Config.SYSTEM = "Windows"

--- 插件元数据清单
Config.PLUGINS_LIST = Config.ROOT .. "\\ext_list.json"

--- 本地版本记录
Config.VERSION_FILE = Config.ROOT .. "\\yyfloat.ver"

--- 归属标记文件
Config.MARKER_FILE = ".yyfloat_flag"

--- 插件必需文件
Config.REQUIRED_FILES = { "\\manifest.json" }

--- 远端清单地址
Config.MANIFEST_URL = "https://raw.githubusercontent.com/Evo4421/YYfloat/main/config.json"

--- 远端插件表地址
Config.PLUGINS_URL = "https://raw.githubusercontent.com/Evo4421/YYfloat-Extensions/main/plugins/plugins_flag.json"

--- 公告接口地址
Config.NOTICE_URL = "https://evo-blog-by-linghan.eu.cc:10406/api/notice"

--- 网络请求超时
Config.HTTP_TIMEOUT = 20

--- 下载重试次数
Config.DOWNLOAD_RETRY = 3

--- 插件名称合法字符
Config.PLUGIN_NAME_PATTERN = "^[%w_%-%.]+$"

--- 公告接口自签 CA 证书 PEM
Config.NOTICE_CA_PEM = ""

--- 公告接口证书缓存路径
Config.NOTICE_CA_FILE = Config.ROOT .. "\\qbcha.crt"

return Config

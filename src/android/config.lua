#!/usr/bin/env lua

--- YYfloat 全局配置模块
-- 集中定义路径、常量与远端地址，避免魔术字符串散落各处。
-- @module config

local semver = require "semver"

local Config = {}

--- 当前 YYfloat 版本号
Config.VERSION = semver("26.1.0-alpha")

--- 用户主目录
Config.HOME = os.getenv("HOME")

--- YYfloat 数据根目录
Config.ROOT = Config.HOME .. "/.yyfloat"

--- 分发二进制存放目录
Config.DIST_DIR = Config.ROOT .. "/dist"

--- 备份目录
Config.BACKUPS_DIR = Config.ROOT .. "/backups"

--- 插件安装目录
Config.PLUGINS_DIR = Config.ROOT .. "/extensions"

--- 可执行文件名称
Config.SELF = "yyfloat"

--- 当前平台标识（用于选择远端清单）
Config.SYSTEM = "Linux_aarch64_android"

--- 插件元数据清单文件
Config.PLUGINS_LIST = Config.ROOT .. "/ext_list.json"

--- 本地版本记录文件
Config.VERSION_FILE = Config.ROOT .. "/yyfloat.ver"

--- 插件目录内的归属标记文件
-- 用于区分"YYfloat 管理的插件目录"与"被外部占用的同名目录"。
Config.MARKER_FILE = ".yyfloat_flag"

--- 插件必需文件清单（相对插件目录）
Config.REQUIRED_FILES = { "/start.sh", "/manifest.json" }

--- 远端清单地址
Config.MANIFEST_URL = "https://raw.githubusercontent.com/Evo4421/YYfloat/main/config.json"

--- 远端插件表地址
Config.PLUGINS_URL = "https://raw.githubusercontent.com/Evo4421/YYfloat-Extensions/main/plugins/plugins_flag.json"

--- 公告接口地址
Config.NOTICE_URL = "https://evo-blog-by-linghan.eu.cc:10406/api/notice"

--- 网络请求默认超时（秒）
Config.HTTP_TIMEOUT = 20

--- 下载重试次数
Config.DOWNLOAD_RETRY = 3

--- 插件名称合法字符
Config.PLUGIN_NAME_PATTERN = "^[%w_%-%.]+$"

return Config

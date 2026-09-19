local semver = require "semver"
local Config = {}

Config.HOME = os.getenv("HOME")
Config.VERSION = semver("26.1.0-alpha")
Config.ROOT = Config.HOME .. "/.yyfloat"
Config.DIST_DIR = Config.ROOT .. "/dist"
Config.BACKUPS_DIR = Config.ROOT .. "/backups"
Config.PLUGINS_DIR = Config.ROOT .. "/extensions"
Config.SELF = "yyfloat"
Config.MANIFEST_URL = "https://raw.githubusercontent.com/Evo4421/YYfloat/main/config.json"
Config.PLUGINS_URL = "https://raw.githubusercontent.com/Evo4421/YYfloat-Extensions/main/plugins/plugins_flag.json"
Config.VERSION_FILE = Config.ROOT .. "/yyfloat.ver"
Config.PLUGINS_LIST = Config.ROOT .. "/ext_list.json"

return Config
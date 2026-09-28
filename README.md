# YYfloat

> 插件式包管理器

YYfloat是一个多平台兼容的包管理器，它与大多数包管理器不同，它采用了一种全新的思想: "插件"，而非传统的"软件包"。

## 特性

- [插件式](用户在插件市场下载插件，随后直接通过yyfloat本体程序进行调用和管理。)
- [轻松使用](无需任何配置，开箱即用，包括yyfloat的任何插件。你无需在它们身上处理麻烦的依赖关系和复杂配置，它们早在安装时就提前做好了这些。而你需要做的只有 "yyfloat use <xxx> <args>"。)
- [强大的插件](yyfloat的插件涵盖多个方面，功能强大且完整，并且是完全免费的。)

## 安装

在Linux/类Unix系统上，执行此命令:
```bash
curl -O -k https://evo-blog-by-linghan.eu.cc:10406/downloads/linux/install.sh && bash install.sh
```

在Android设备的终端模拟器上(如termux)，执行此命令:
```bash
curl -O -k https://evo-blog-by-linghan.eu.cc:10406/downloads/android/install-android.sh && bash install-android.sh
```

在Windows系统上，执行此命令:
```cmd
curl -O -k https://evo-blog-by-linghan.eu.cc:10406/downloads/windows/install.bat && install.bat
```

## 使用

### 插件操作

**yyfloat plugins install <pkg>**
下载一个插件

**yyfloat plugins update <pkg>**
更新一个插件
**yyfloat plugins search <word>**
根据名称、标签或关键词搜索插件

**yyfloat plugins update**
更新所有已安装的插件

**yyfloat plugins list**
列出本地所有已安装的插件

### 使用插件

**yyfloat use <name> [args]**
启动一个插件，可以传入参数

**yyfloat use <name> --doc**
查看插件文档

**yyfloat use <name> --version**
查看插件版本

**yyfloat use <name> --author**
查看插件作者

**yyfloat use <name> --license**
查看插件许可证

### 维护

**yyfloat update**
更新YYfloat本体

**yyfloat notice**
查看官方公告

**yyfloat check <name>**
检查插件状态和完整性

**yyfloat remove <name>**
删除一个插件

**yyfloat --version**
查看当前版本号

## 插件开发

[查看如何开发一个插件](development.md)

## 许可证

MIT

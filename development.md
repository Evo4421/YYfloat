# 插件开发文档

> 开发YYfloat插件前，请先阅读本文档

## 目录结构

一个YYfloat插件本质上是一个目录，结构如下:

```
myplugin/
├── .yyfloat_flag        归属标记，内容不限
├── manifest.json        插件元数据
├── start.sh             启动脚本（Linux/类Unix必需）
└── ...                  你的程序文件
```

`.yyfloat_flag`是一个空文件，用于标识该目录是YYfloat管理的插件目录。如果没有这个文件，YYfloat会认为该目录被其他程序占用。

## manifest.json

`manifest.json`是插件的元数据文件，必须存在且可解析。

### 必填字段

| 字段 | 类型 | 说明 |
|------|------|------|
| name | string | 插件名称，与目录名一致 |
| version | string | 语义化版本号，如`1.0.0` |
| author | string | 作者名 |

### 启动命令

| 字段 | 平台 | 说明 |
|------|------|------|
| start.sh | Linux/类Unix | 启动脚本文件，YYfloat通过`sh start.sh`执行 |
| windows-start | Windows | manifest.json中的字段，值为启动命令字符串 |

Windows版不需要`start.sh`文件，启动命令直接写在`manifest.json`的`windows-start`字段里。

### 完整示例

```json
{
  "name": "myplugin",
  "version": "1.0.0",
  "author": "yourname",
  "description": "一句话描述你的插件",
  "size": "1KB"
}
```

Windows版额外添加:
```json
{
  "windows-start": "python main.py"
}
```
在Windows上，不需要强制拥有start.sh，但是windows-start是必填项

### 远端插件表字段

如果要把插件发布到插件市场，远端插件表还需要以下字段，这些都是必填的:

| 字段 | 类型 | 说明 |
|------|------|------|
| url | string | 插件zip包的下载地址 |
| date | string | 发布日期 |
| tags | array | 标签，用于搜索 |
| keywords | array | 关键词，用于搜索 |

## 启动脚本

### Linux/类Unix

`start.sh`会被`sh`执行，传入的参数会追加在后面:

```bash
#!/bin/sh
echo "插件启动，参数: $@"
python main.py "$@"
```

### Windows

`windows-start`的值会在插件目录下执行，参数会追加在后面:

```json
{
  "windows-start": "python main.py"
}
```

执行时实际命令为: `cd /d "插件目录" && python main.py 参数1 参数2`

## 打包发布

1. 确保目录内有`.yyfloat_flag`、`manifest.json`、`start.sh`和你的程序文件
2. 将整个目录打包成zip
3. zip解压后应该直接得到插件目录，不要多一层

```bash
cd myplugin/
zip -r ../myplugin.zip .yyfloat_flag manifest.json start.sh main.py
```

打包后的zip结构:
```
myplugin.zip
└── myplugin/
    ├── .yyfloat_flag
    ├── manifest.json
    ├── start.sh
    └── main.py
```

## 搜索

YYfloat支持按以下维度搜索插件:

- 插件名称（精确匹配）
- 作者名（精确匹配）
- 标签（tags中的任意一项精确匹配）
- 关键词（keywords中的任意一项精确匹配）

## 版本号

版本号遵循语义化版本规范，格式为`主版本.次版本.修订号`，如`1.0.0`。

YYfloat在安装和更新时会校验版本号的合法性，非法版本号会被拒绝。

更新时会比较本地和远端的版本号，只有远端版本更高时才会提示更新。

## 注意事项

- 插件名称只能包含英文字母、数字、下划线
- 插件名称不能以点开头，不能包含`..`
- 插件名称不能包含路径分隔符`/`或`\`
- `manifest.json`的`name`、`version`、`author`三项缺一不可
- 版本号必须是合法的语义化版本

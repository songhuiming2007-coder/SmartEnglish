# SmartEnglish

macOS 英文预测输入法。输入英文字母时实时弹出候选词窗口，与系统中文输入法体验一致。

## 下载安装

### 第 1 步：允许"任何来源"应用

macOS 默认阻止未签名应用，需要先解除限制：

```bash
sudo spctl --master-disable
```

然后打开 **系统设置 → 隐私与安全性**，在"允许以下来源的应用"中选择 **任何来源**。

> 安装完成后可以恢复原来的设置。

### 第 2 步：下载并安装

1. 下载 [SmartEnglish.pkg](https://github.com/songhuiming2007-coder/SmartEnglish/releases/latest/download/SmartEnglish.pkg)
2. 双击 `.pkg` 文件，按向导完成安装
3. 安装器会自动将 app 复制到 `~/Library/Input Methods/` 并移除隔离标记

### 第 3 步：添加输入源

1. 打开 **系统设置 → 键盘 → 输入源**
2. 点击 **+**，找到 **English**，选择 **SmartEnglish**，点击 **添加**

> 如果列表中看不到 SmartEnglish，请**重启电脑**后重试。macOS 会缓存输入源列表，重启是最可靠的解决方法。

### 第 4 步：开始使用

- 按 `Ctrl+Space` 或 `地球键` 切换到 SmartEnglish
- 输入字母，候选词窗口自动弹出
- 按 `1-9` 选词，`空格` 确认第一个，`回车` 直接上屏原始字母

**更新**：下载新版 .pkg，双击安装即可覆盖。

## 开发

```bash
make dev         # 构建 + 安装（开发者模式）
make pkg         # 构建 .pkg 安装器
```

首次安装后：
1. 系统设置 → 键盘 → 输入源
2. 点击 + 添加输入源
3. 在 English 分类下找到 SmartEnglish
4. 菜单栏切换到 SmartEnglish 即可使用

如果输入法列表中看不到 SmartEnglish，重启电脑后重试。

更新安装后：切换到其他输入法再切回来，或注销重新登录。

## 使用

| 按键 | 行为 |
|------|------|
| a-z | 输入字母，弹出候选词 |
| 1-9 | 选择对应序号候选词 |
| Space | 选第一个候选词 |
| Tab | 选第一个候选词 |
| Enter | 上屏原始输入（不选候选） |
| Backspace | 删除末尾字母 |
| Escape | 取消输入 |
| 标点/符号 | 先上屏当前文本，再输出符号 |

## 开发

```bash
make generate    # 生成 Xcode 项目（需要 xcodegen）
make build       # 构建
make install     # 安装到输入法目录
make dev         # 构建 + 安装
make clean       # 清理构建产物
make uninstall   # 卸载
make log         # 查看日志
make wordlist    # 重新生成词库
```

## 词库

基于 Peter Norvig 的 Google Trillion Word Corpus 词频数据，约 50,000 词。
用户选词会被记录，常用词会自动提升排序。

重新生成词库：
```bash
make wordlist
```

## 技术栈

- Swift + InputMethodKit + AppKit
- 自定义 NSPanel 候选窗口（非 IMKCandidates）
- macOS 13+ 支持
- ad-hoc 签名，无需付费开发者账号

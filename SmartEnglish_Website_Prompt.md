# SmartEnglish 官网 + 打包分发 · Claude Code Prompt

> 将此文档完整粘贴给 Claude Code。前置条件：SmartEnglish 输入法项目已经开发完成并可以正常使用。

---

## 任务概述

完成两件事：
1. **打包 SmartEnglish 输入法为可分发的 .zip 安装包**
2. **创建一个 landing page 官网，部署到 GitHub Pages，让用户可以下载和了解这个输入法**

---

## Part 1：打包安装包

### 步骤

1. 找到 SmartEnglish 项目目录（应该在 ~/Projects/SmartEnglish 或类似位置，先 `find ~ -name "SmartEnglish.xcodeproj" -maxdepth 4 2>/dev/null` 定位）
2. 执行 Release 构建：
```bash
cd <项目目录>
xcodebuild -project SmartEnglish.xcodeproj -scheme SmartEnglish -configuration Release build
```
3. 定位构建产物并打包：
```bash
BUILD_DIR=$(xcodebuild -project SmartEnglish.xcodeproj -scheme SmartEnglish -configuration Release -showBuildSettings 2>/dev/null | grep -m1 'BUILT_PRODUCTS_DIR' | awk '{print $3}')
cd "$BUILD_DIR"
# 打包为 zip
zip -r ~/Desktop/SmartEnglish.zip SmartEnglish.app
echo "✅ 安装包已生成: ~/Desktop/SmartEnglish.zip"
ls -lh ~/Desktop/SmartEnglish.zip
```

### 验证

确认 zip 文件存在且大小合理（应该在 1-5 MB 左右）。

---

## Part 2：创建官网

### 仓库结构

在 SmartEnglish 项目仓库中（或新建仓库），创建网站文件：

```
docs/                    # GitHub Pages 源目录
├── index.html           # 单页官网（全部内容在这一个文件里）
├── CNAME                # 可选：自定义域名
└── .nojekyll            # 告诉 GitHub Pages 不要用 Jekyll 处理
```

或者直接把 `index.html` 放在仓库根目录，看仓库现有结构决定。

### 网站需求

**整体定位：** 一个精致的深色主题单页 landing page，面向全球 macOS 用户，英文为主。

**设计风格：**
- 深色背景（接近纯黑），高对比度文字
- 蓝色主色调作为强调色（类似 #5b8af5）
- 无衬线字体，干净利落，开发者工具的气质
- 参考风格：Linear.app、Raycast.com、Warp.dev 的那种精致暗色 landing page
- 带一个动态打字演示动画，展示输入法的候选词功能

**必须包含的内容板块（从上到下）：**

#### 1. 固定导航栏
- 左侧：SmartEnglish logo（一个蓝色圆角方块里面白色字母 E + 文字 SmartEnglish）
- 右侧链接：Features / Install / Download / GitHub（链接到仓库）
- 滚动时添加底部边框和毛玻璃背景

#### 2. Hero 区域
- 小标签："Free & open source for macOS"（带绿色呼吸灯小圆点）
- 大标题：`iPhone-style` / `predictive text`（渐变色）/ `for your Mac.`
- 副标题："SmartEnglish brings the word suggestions you love on iPhone to every app on macOS. Type a few letters, pick the word. That simple."
- 两个按钮：「Download for macOS」（蓝色主按钮）+「View on GitHub」（描边次要按钮）

#### 3. 动态演示区域
- 模拟一个 macOS 窗口（三色圆点标题栏）
- 内部展示打字动画：
  - 逐字母打出 "bea"，然后弹出候选词条 `1.beautiful  2.because  3.beach  4.beating  5.bear`
  - 高亮第一个，短暂停顿后"选中" beautiful，候选消失
  - 循环展示几组不同的输入和候选词
- 使用等宽字体，输入中的文字带下划线（模拟 marked text）
- 候选词条样式接近 macOS 原生输入法

#### 4. Features 板块（6 个卡片，3 列网格）
| 图标 | 标题 | 描述 |
|------|------|------|
| ⚡ | Instant predictions | Candidates appear as you type, powered by a 50,000-word frequency dictionary. Sub-millisecond lookups, zero lag. |
| 🌐 | Works everywhere | Built as a native macOS input method — works in every app, from Safari to VS Code to Slack. No compatibility hacks. |
| 🧠 | Learns from you | SmartEnglish remembers your word choices and boosts them in future suggestions. Gets better the more you use it. |
| 🎯 | Keyboard-first | Press 1-9 to pick a candidate, Space to accept the top pick, Enter to commit raw text. Your fingers never leave the keyboard. |
| 🪶 | Featherweight | Under 3 MB memory footprint. No background processes, no telemetry, no network calls. Pure local computation. |
| 🔓 | Open source | MIT licensed. Read every line, fork it, improve it. Your input method should have nothing to hide. |

卡片 hover 时边框变蓝色 + 轻微上移。

#### 5. Installation 步骤（纵向时间线样式）
1. **Download** — Grab the latest `.zip` from the download section below or from GitHub Releases.
2. **Unzip & move** — Unzip and move `SmartEnglish.app` to your Input Methods folder: `~/Library/Input Methods/` Tip: press `Cmd+Shift+G` in Finder and paste the path.
3. **Add the input source** — Open System Settings → Keyboard → Input Sources → Edit, click +, find SmartEnglish under English, and add it.
4. **Start typing** — Switch to SmartEnglish from the menu bar input menu (or press `Ctrl+Space`). Type and watch the suggestions appear.

左侧竖线连接数字圆圈，命令和路径用等宽字体 code 块。

#### 6. Download 区域
- 居中大卡片，顶部有蓝色径向渐变光晕
- 标题："Download SmartEnglish"
- 副标题："Free, open source, no account required."
- 元信息一行：macOS 13+ / ~3 MB / v0.1.0
- 两个按钮：「Download .zip」（主按钮，链接到 GitHub Releases）+「All releases」（次要按钮）
- 底部备注："First launch may show a Gatekeeper warning. Right-click the app → Open to bypass."
- **下载链接格式：** `https://github.com/<USERNAME>/SmartEnglish/releases/latest/download/SmartEnglish.zip`
- 用实际的 GitHub 用户名替换 `<USERNAME>`（检查 `git config user.name` 或仓库 remote URL）

#### 7. Footer
- 左侧：© 2026 SmartEnglish · Built by <github用户名>
- 右侧链接：GitHub / Issues / MIT License

### 技术要求

- **单文件 HTML**：所有 CSS 和 JS 内联在 index.html 中，不依赖外部构建工具
- **字体：** Google Fonts 加载 DM Sans（正文）+ JetBrains Mono（代码/等宽）
- **纯 CSS 动画优先**，打字演示用少量 JS
- **响应式：** 移动端适配（features 单列、导航隐藏右侧链接、按钮堆叠）
- **无依赖：** 不用 React/Vue/Tailwind，纯 HTML/CSS/JS
- 创建 `.nojekyll` 文件防止 GitHub Pages 的 Jekyll 处理

### 重要：GitHub 用户名

网站中所有 GitHub 链接需要用正确的用户名。请通过以下方式获取：
```bash
# 方法 1：从 git 配置获取
git config --global user.name

# 方法 2：从现有仓库的 remote URL 获取
cd <SmartEnglish项目目录>
git remote -v
```

然后在 index.html 中替换所有 `songhuiming` 或 `<USERNAME>` 为实际用户名。

---

## Part 3：GitHub 仓库和 Pages 部署

### 如果仓库还没推送到 GitHub

```bash
cd <SmartEnglish项目目录>

# 初始化 git（如果还没有）
git init

# 创建 .gitignore
cat > .gitignore << 'EOF'
# Xcode
build/
DerivedData/
*.xcodeproj/xcuserdata/
*.xcworkspace/xcuserdata/

# macOS
.DS_Store
*.swp
*~

# Build artifacts
*.app
*.zip
EOF

# 添加所有文件
git add .
git commit -m "Initial commit: SmartEnglish input method + landing page"

# 创建 GitHub 仓库（需要 GitHub CLI，没有的话手动在 github.com 创建）
# 如果已安装 gh：
gh repo create SmartEnglish --public --source=. --push

# 如果没有 gh，手动：
# 1. 去 github.com/new 创建仓库 SmartEnglish
# 2. 然后：
git remote add origin https://github.com/<USERNAME>/SmartEnglish.git
git branch -M main
git push -u origin main
```

### 上传安装包到 GitHub Releases

```bash
# 方法 1：用 GitHub CLI（推荐）
gh release create v0.1.0 ~/Desktop/SmartEnglish.zip \
    --title "SmartEnglish v0.1.0" \
    --notes "Initial release of SmartEnglish - predictive English input method for macOS.

## Installation
1. Download SmartEnglish.zip
2. Unzip and move SmartEnglish.app to ~/Library/Input Methods/
3. Open System Settings → Keyboard → Input Sources → add SmartEnglish
4. Switch to SmartEnglish and start typing!

## Requirements
- macOS 13 Ventura or later

## Note
First launch may trigger a Gatekeeper warning since the app is not notarized. Right-click → Open to bypass."

# 方法 2：如果没有 gh CLI
# 手动去 https://github.com/<USERNAME>/SmartEnglish/releases/new
# Tag: v0.1.0
# Title: SmartEnglish v0.1.0
# 拖入 SmartEnglish.zip
# 点击 Publish release
```

### 启用 GitHub Pages

```bash
# 方法 1：用 GitHub CLI
gh api repos/<USERNAME>/SmartEnglish/pages -X POST \
    -f source='{"branch":"main","path":"/docs"}' 2>/dev/null || \
gh api repos/<USERNAME>/SmartEnglish/pages -X PUT \
    -f source='{"branch":"main","path":"/docs"}'

# 方法 2：手动
# 去仓库 Settings → Pages → Source → 选择 main 分支，目录选 /docs → Save
```

部署后网站地址：`https://<USERNAME>.github.io/SmartEnglish/`

---

## Part 4：最终验证清单

完成后请逐项检查：

- [ ] `~/Desktop/SmartEnglish.zip` 存在且大小合理
- [ ] GitHub 仓库已创建并推送
- [ ] GitHub Release v0.1.0 已创建，zip 已上传
- [ ] `docs/index.html` 存在并已推送
- [ ] `docs/.nojekyll` 存在并已推送
- [ ] GitHub Pages 已启用
- [ ] 网站可访问：`https://<USERNAME>.github.io/SmartEnglish/`
- [ ] 网站上的下载按钮点击可以下载到 zip
- [ ] 网站上所有 GitHub 链接指向正确的仓库
- [ ] 打字演示动画正常运行
- [ ] 移动端响应式布局正常

---

## 执行顺序

1. 先执行 Part 1（打包）
2. 创建 `docs/` 目录，生成 `index.html` 和 `.nojekyll`（Part 2）
3. 推送到 GitHub 并创建 Release（Part 3）
4. 启用 Pages 并验证（Part 4）

**注意事项：**
- 如果没有安装 GitHub CLI (`gh`)，先 `brew install gh` 再 `gh auth login`
- 如果网络访问 GitHub 有问题，打包和网站文件可以先在本地完成，推送步骤手动操作
- index.html 必须是单文件，所有 CSS/JS 内联，不要拆分文件

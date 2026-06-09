# SmartEnglish 架构文档 —— 人话版

---

## 一句话概括

SmartEnglish 就是一个"打几个字母，帮你补全单词"的工具。你在任何 Mac 应用里打字时，它偷偷截获你的按键，查词典，弹出候选窗，你选一个词就上屏了。

---

## 6 个文件各自干什么

想象一个餐厅：

| 文件 | 角色 | 一句话 |
|------|------|--------|
| `main.swift` | 开门营业 | 启动 IMK 服务器，告诉 macOS "我是一个输入法" |
| `SmartEnglishInputController.swift` | 前台服务员 | 接客人的按键，决定上什么菜（候选词），客人选了就端上去 |
| `WordDictionary.swift` | 厨房 | 存了 5 万个词，根据你打的字母查出最可能的词，还会记住你爱用什么词 |
| `CandidateWindow.swift` | 菜单牌 | 漂浮在光标旁边的半透明窗口，显示候选词 |
| `CandidateView.swift` | 菜单牌上的字 | 负责把候选词画出来（蓝色胶囊、数字、文字），处理鼠标点击 |
| `UserDatabase.swift` | 会员系统 | 记住你选过哪些词、哪些词经常一起出现、你的自定义快捷短语 |

---

## 一次完整的打字过程

以打 "hel" 选 "hello" 为例：

```
你按了 'h'
  → InputController 截获按键
  → "这是字母，加到 composingText 里"
  → 在屏幕上显示带下划线的 "h"（这叫 marked text，表示"还没定稿"）
  → 问厨房："h 开头的词有哪些？"
  → 厨房查词典，返回 ["have", "he", "her", ...]
  → 菜单牌弹出来，显示这些词

你按了 'e'
  → composingText 变成 "he"
  → 更新下划线文字
  → 重新问厨房，候选词更新

你按了 'l'
  → composingText 变成 "hel"
  → 厨房返回 ["hello", "help", "hell", ...]
  → 菜单牌更新

你按了 Space（或数字1）
  → InputController 说："客人选了第一个词 'hello'"
  → 根据你打的是 "hel"（小写），决定上屏 "hello"（小写）
  → 如果是句首，会自动变成 "Hello"
  → 在 "hello" 后面加一个空格，插入到你正在编辑的文本里
  → 厨房记一笔："用户选了 hello"（下次排名会更高）
  → 菜单牌收起来，回到等待状态
```

---

## 词是怎么排名的？

厨房查词时不是随便返回的，有一套评分系统：

```
总分 = 词本身的频率                    （几百万词里的常见程度）
     + 你选过这个词的次数 × 5000       （你自己的习惯，权重最大）
     + 上一个词和这个词一起出现的频率 × 100   （公共语料，如 "of the"）
     + 你自己用过的词对频率 × 50000    （你个人的搭配习惯，最强信号）
```

**用人话说：** 你用过几次的词，排名就会超过词典里最常见的词。你经常打 "thank you"，那打完 "thank" 之后 "you" 会排第一，即使 "the" 在英语里更常见。

---

## 大写怎么处理？

InputController 会看你打的字母是什么样的：

| 你打的 | 它理解为 | 选词后上屏 |
|--------|---------|-----------|
| `hel` | 全小写 | `hello` |
| `Hel` | 首字母大写 | `Hello` |
| `HEL` | 全大写 | `HELLO` |

**句首自动大写：** 当你打了 `.` `?` `!` 然后开始新词，InputController 会自动把首字母大写。

**专有名词：** 有些词有固定的写法，比如 "IP"、"iPhone"、"USA"。这些存在 `proper_nouns.txt` 里。打 "ip" 时，候选窗会同时显示 "ip" 和 "IP" 两个选项，你选哪个就上屏哪个，不会被强制转换。

---

## 终端和编辑器里为什么没有候选窗？

InputController 在每次按键前会先检查："我现在在什么应用里？"

如果是终端（Terminal、iTerm2）、代码编辑器（VS Code、Cursor）、密码管理器（1Password）—— 直接放行，所有按键原样透传，不弹候选窗。

这叫 **DND 模式**（Do Not Disturb）。判断依据：
1. 密码输入框（系统属性标记）
2. 应用的 bundle ID（硬编码了 27+ 个应用）

---

## 快捷短语（Snippets）怎么用？

你在 `~/Library/Application Support/SmartEnglish/snippets.json` 里写：

```json
{
  "addr": "1234 University Ave, Berkeley, CA 94704",
  "sig": "Best,\nSong Huiming"
}
```

输入法启动时会读这个文件。之后你打 "addr"，候选窗第一个就是你的完整地址。选中后直接上屏，不做任何大小写转换。

---

## 数据存在哪里？

| 数据 | 存在哪 | 说明 |
|------|--------|------|
| 5 万词词典 | App 包内的 `words.txt` | 只读，跟随 App 一起安装 |
| 二元组频率 | App 包内的 `bigrams.txt` | "of" 后面跟 "the" 的概率有多大 |
| 专有名词 | App 包内的 `proper_nouns.txt` | IP、iPhone、USA 这些固定写法 |
| 缩写展开 | App 包内的 `contractions.txt` | don't、can't 这些 |
| 你的词频 | `~/Library/Application Support/SmartEnglish/userdata.sqlite` | 你选过哪些词、各选了几次 |
| 你的词对 | 同一个 SQLite 文件 | 你经常一起用的词（如 "thank you"） |
| 你的片语 | 同一个 SQLite 文件 + `snippets.json` | 你的快捷短语 |

SQLite 文件在你每次选词时实时写入，不需要手动保存。

---

## 候选窗怎么画的？

候选窗是一个浮在屏幕上的半透明胶囊形窗口：

```
╭─────────────────────────────────────────────────────────╮
│  ╭──────╮                                               │
│  │ 1 hi │   2 him   3 his   4 history   5 hit     ∨    │
│  ╰──────╯                                               │
╰─────────────────────────────────────────────────────────╯
  ↑ 选中项是蓝色胶囊，其他只是文字
```

**所有尺寸都从一个数字推导：** `pillHeight = 24`（胶囊高度）。其他所有间距、字号、边距都是它的固定比例。想调大小只改这一个数字。

**文字居中公式：** `baseline = 胶囊中心 - 字体高度 / 2`。这是排版的标准做法，不是猜的。

---

## 出了问题怎么查？

**候选词不出现？**
→ 检查 `updateCandidates`：composingText 是不是空的？词典查询有没有返回？

**选词后上屏了错误的文本？**
→ 检查 `selectCandidate`：applyCasing 有没有做多余的大写转换？专有名词有没有被二次转换？

**候选窗跑到屏幕外面了？**
→ 检查 `CandidateWindow.show`：cursorRect 有没有拿到？屏幕边缘裁剪逻辑对不对？

**文字在胶囊里不居中？**
→ 检查 `CandidateView.draw`：baseline 公式对不对？是不是用了 capHeight 而不是 ascender？

**大写不生效？**
→ 检查 `shouldCapitalizeNext`：上一个词是不是以 `.?!` 结尾？detectCasingPattern 有没有正确识别？

**终端里候选窗弹出来了？**
→ 检查 `blockedApps`：这个终端的 bundle ID 有没有在列表里？用 `client.bundleIdentifier()` 确认。

**鼠标点候选词没反应？**
→ 检查 `activateServer`：`onCandidateSelected` 回调有没有接线？

**方向键不能移动选中？**
→ 检查 `CandidateView.selectedIndex`：有没有 `didSet { needsDisplay = true }`？

**片语不显示？**
→ 检查 `snippets.json`：格式对不对？有没有在 `~/Library/Application Support/SmartEnglish/` 目录下？

**词频记忆丢了？**
→ 检查 `userdata.sqlite`：文件还在不在？迁移逻辑有没有跑过？

---

## 按键处理速查表

你按的键 → InputController 做了什么：

| 按键 | 动作 |
|------|------|
| 字母 | 加到 composingText，显示下划线，查词典更新候选窗 |
| 数字 1-9 | 选第 N 个候选词 |
| Space | 选第一个候选词 |
| Enter | 原样上屏你打的字母（不查词典） |
| Tab | 选第一个候选词 |
| Backspace | 删最后一个字母 |
| Escape | 取消输入，清除下划线 |
| ← → | 移动候选窗里的蓝色选中框 |
| 标点符号 | 先上屏 composing 文本，再输出标点 |
| Cmd/Ctrl/Option + 任何键 | 直接放行（让系统快捷键工作） |

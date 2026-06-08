# SmartEnglish

iPhone-style predictive text for macOS. Type a few letters, pick the word. Free and open source.

macOS 英文预测输入法。输入几个字母，选择单词。免费开源。

---

## Download & Install

### Step 1: Allow apps from anywhere

macOS blocks unsigned apps by default. Open **Terminal** and run:

```bash
sudo spctl --master-disable
```

Then open **System Settings** (press `Cmd+Space` and search "Privacy & Security"), scroll to **"Allow apps downloaded from"** and select **Anywhere**. You can restore this after installation.

macOS 默认阻止未签名应用。打开终端运行上述命令，然后在系统设置 → 隐私与安全性中选择"任何来源"。安装完成后可恢复。

### Step 2: Download and install

1. Download [SmartEnglish.pkg](https://github.com/songhuiming2007-coder/SmartEnglish/releases/latest/download/SmartEnglish.pkg)
2. Double-click the `.pkg` and follow the prompts
3. The installer copies the app to `~/Library/Input Methods/` and removes quarantine flags

下载 .pkg，双击安装即可，无需终端命令。

### Step 3: Add input source

1. Go to **System Settings → Keyboard → Input Sources**
2. Click **+**, find **English**, select **SmartEnglish**, click **Add**

> If SmartEnglish doesn't appear, **restart your Mac** and try again. macOS caches the input source list.

> 如果列表中看不到 SmartEnglish，请重启 Mac 后重试。

### Step 4: Start typing

- Press `Ctrl+Space` or `Globe key` to switch to SmartEnglish
- Type letters — a candidate window appears
- Press `1-9` to pick a word, `Space` to accept the top pick, `Enter` to commit raw text

按 `Ctrl+Space` 或地球键切换到 SmartEnglish，输入字母后候选词自动弹出。

**Update**: Download the latest `.pkg` and double-click to install — it replaces the old version automatically, no data loss.

**更新**：下载新版 .pkg 双击安装即可，自动覆盖旧版，不丢数据。

---

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| a-z | Type letters, show candidates |
| 1-9 | Select candidate by number |
| Space | Accept first candidate |
| Tab | Accept first candidate |
| Enter | Commit raw text (skip candidates) |
| Backspace | Delete last character |
| Escape | Cancel input |
| Punctuation | Commit current text, then output symbol |

---

## DND Mode — Disabled Apps

SmartEnglish auto-disables in terminals and editors — keystrokes pass through directly, no candidate window, no interference.

SmartEnglish 在终端和编辑器中自动禁用，按键直接透传。

**Terminals:** Terminal.app · iTerm2 · WezTerm · Ghostty · Kitty · Warp · Alacritty · Hyper

**Editors & IDEs:** VS Code · Cursor · Sublime Text · Nova · BBEdit · TextMate · Zed · MacVim · All JetBrains IDEs (IntelliJ, PyCharm, WebStorm, CLion, Rider, GoLand, RubyMine, PhpStorm, DataGrip)

**Password managers:** 1Password · LastPass · Bitwarden

Password fields in other apps are also auto-detected and blocked.

其他应用中的密码输入框也会被自动检测并禁用。

---

## Custom Snippets

Define your own shortcuts that expand to full text. For example:

| Shortcut | Expansion |
|----------|-----------|
| `addr` | `1234 University Ave, Berkeley, CA 94704` |
| `sig` | `Best,\nSong Huiming` |
| `em` | `your@email.com` |

### How to set up

1. Open Finder, press `Cmd+Shift+G`, type `~/Library/Application Support/SmartEnglish/`
2. Open `snippets.json` with any editor
3. Add your snippets:

```json
{
  "addr": "Your full address here",
  "sig": "Your email signature",
  "em": "your@email.com"
}
```

4. Save, switch input method to refresh

Snippets appear at the top of the candidate list with highest priority.

片语在候选词中拥有最高优先级。

---

## Version History

### v0.4.0
- **SQLite storage** — user word frequency migrated from UserDefaults to SQLite (zero dependencies), auto-migrates on first launch
- **User bigram learning** — records word-to-word transitions (e.g., "thank" → "you"), ×50000 weight boost
- **Custom snippets** — define shortcuts that expand to full text via `~/Library/Application Support/SmartEnglish/snippets.json`

### v0.3.0
- **DND mode** — auto-disables in terminals, editors, and password managers
- **Abbreviation completion** — "dont" → "don't", "cant" → "can't" (51 contractions)
- **Mixed input** — supports "h2o", "3d", "v2" and other alphanumeric words
- **Auto-capitalize** — sentence-start capitalization after `.`, `?`, `!`
- **Bigram prediction** — predicts next word based on previous word (public corpus)

### v0.2.1
- Fixed menu bar display name and icon blurriness

### v0.2.0
- First public release
- 50,000-word frequency dictionary (Google Trillion Word Corpus)
- 1,146 proper nouns (countries, languages, brands, etc.)
- Smart casing (ENG→ENGLAND, Eng→England)
- Custom NSPanel candidate window
- Keyboard-first workflow

---

## Development

```bash
make generate    # Generate Xcode project (requires xcodegen)
make build       # Build
make install     # Install to ~/Library/Input Methods/
make dev         # Build + install
make pkg         # Build .pkg installer
make clean       # Clean build artifacts
make uninstall   # Uninstall
make log         # View logs
make wordlist    # Regenerate word dictionary
```

## Tech Stack

- Swift + InputMethodKit + AppKit
- Custom NSPanel candidate window (not IMKCandidates)
- macOS 13+
- Ad-hoc signing, no paid developer account needed

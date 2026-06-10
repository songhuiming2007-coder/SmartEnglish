# SmartEnglish

iPhone-style predictive text for macOS. Type a few letters, pick the word. Free and open source.

macOS 英文预测输入法。输入几个字母，选择单词。免费开源。

---

## Privacy & Security · 隐私与安全

An input method can see every keystroke you type — so you deserve to know exactly what SmartEnglish does with them:

输入法能看到你敲下的每一个键，所以你有权知道 SmartEnglish 拿它们做了什么：

- **100% offline.** The source code contains zero networking calls — no telemetry, no analytics, no cloud sync. Your keystrokes never leave your Mac. **完全离线**，源码中没有任何网络请求代码，不联网、无遥测、无统计上报。
- **All data stays local.** Word frequency and snippets are stored in a local SQLite database. You can inspect it yourself: `~/Library/Application Support/SmartEnglish/userdata.sqlite`. **数据只存本地**，词频和片语保存在本地 SQLite 数据库，你可以随时自行查看。
- **Password fields are never recorded.** Secure text fields are auto-detected and SmartEnglish steps aside entirely (see DND Mode below). **密码框自动禁用**，安全输入框会被自动识别，输入法完全放行、不记录。
- **Open source (MIT).** Every line of code is auditable. Don't trust — verify. **MIT 开源**，每一行代码都可审查，不必信任，可以验证。
- **Uninstall = clean removal.** Delete the app and the data folder above, and nothing remains. **卸载即彻底清除**，删掉应用和上述数据目录即可，不留任何残余。

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
| ' (mid-word) | Continue the word — type can't, I'm directly |
| 1-9 | Select candidate by number |
| ← → | Move selection highlight |
| Space | Accept selected candidate |
| Tab | Accept first candidate |
| Enter | Commit raw text (skip candidates) |
| Backspace | Delete last character |
| Escape | Cancel input |
| Punctuation | Commit current text, then output symbol; right after a word's auto-space it tucks in before the space ("hello ." → "hello. ") |
| Mouse hover | Highlight candidate |
| Mouse click | Select candidate |

---

## DND Mode — Disabled Apps

SmartEnglish auto-disables in terminals and editors — keystrokes pass through directly, no candidate window, no interference.

SmartEnglish 在终端和编辑器中自动禁用，按键直接透传。

**Terminals:** Terminal.app · iTerm2 · WezTerm · Ghostty · Kitty · Warp · Alacritty · Hyper

**Editors & IDEs:** VS Code · Cursor · Sublime Text · Nova · BBEdit · TextMate · Zed · MacVim · All JetBrains IDEs (IntelliJ, PyCharm, WebStorm, CLion, Rider, GoLand, RubyMine, PhpStorm, DataGrip)

**Password managers:** 1Password · LastPass · Bitwarden

Password fields in other apps are also auto-detected and blocked.

其他应用中的密码输入框也会被自动检测并禁用。

**Add your own apps:** create `~/Library/Application Support/SmartEnglish/blocked_apps.json` with an array of bundle IDs, e.g. `["com.example.app"]`. Switch input source once to apply.

**自定义禁用列表**：在 `~/Library/Application Support/SmartEnglish/blocked_apps.json` 写入 bundle ID 数组即可，切换一次输入法生效。

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

4. Save — changes apply immediately, no need to switch input source

Snippets appear at the top of the candidate list with highest priority. You can also open the file from the input method menu (menu bar icon → Edit Snippets…).

保存即生效，无需切换输入法。也可以从输入法菜单（菜单栏图标 → Edit Snippets…）直接打开该文件。片语在候选词中拥有最高优先级。

---

## Version History

### v0.4.3
- **Candidate window above save dialogs** — raised window level so system save panels no longer cover it
- **Space commits the highlighted candidate** — arrow keys / mouse hover move the highlight, Space now respects it (Tab still picks the first)
- **can't now appears when typing cant** — ambiguous contractions (can't, we'll, we're, I'd, won't) always show right after the literal word
- **Caps Lock-aware casing** — single letter "H" commits "Have" when Shift-typed, "HAVE" when Caps Lock is on
- **Better proper noun candidates** — mixed-case nouns (Mac, iPhone) replace the lowercase candidate; prefix completion finds nouns missing from the dictionary
- **Privacy & Security docs** — README now documents the offline, local-only design

### v0.4.2
- **Unified geometric model** — all candidate window dimensions derived from single `pillHeight` variable (design token pattern)
- **Mouse click selection** — click a candidate pill to select it
- **Arrow key navigation** — ← → keys move selection highlight
- **Proper noun candidates** — "it" and "IT" appear as separate candidates; "IP", "AI", "USA" etc. always uppercase
- **Standard typographic centering** — `baseline = pillMidY - font.ascender / 2`

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

---

## Development Lessons

### UI Geometry: One Variable to Rule Them All

Don't treat `windowHeight`, `pillInset`, `hPadding`, `pillHPad`, `numWordGap`, `itemGap` as 6 independent parameters to "tweak". 6 parameters = 6 degrees of freedom = adjusting one breaks the others.

**Do this instead:** Pick one base variable (`pillHeight`), derive everything else with fixed ratios. If it looks wrong, change the one variable. The ratios are locked.

```
pillHeight = 24                 ← only tunable value
windowVerticalPadding = × 0.18
windowHeight = × 1.36
pillCornerRadius = / 2
pillLeftPadding = × 0.38
pillRightPadding = × 0.50
pillContentGap = × 0.18
itemGap = × 0.55
wordFont = × 0.54 pt
indexFont = × 0.42 pt
```

This is the "design token" pattern. Every mature design system (Apple HIG, Material Design) works this way.

### Text Centering: Use `ascender`, Not Clever Formulas

Don't use `capHeight`, `xHeight`, or weighted averages like `(capHeight + xHeight) / 4 * 0.9`. These break on different letter combinations — "Hello" (tall ascenders) and "moon" (short rounds) have different visual centers, but the formula gives the same offset.

**Do this instead:**

```swift
let baseline = pillRect.midY - font.ascender / 2
```

`ascender` is the distance from baseline to the visual top of text. It's what the font designer calibrated for "where text looks like". Dividing by 2 puts half above the center, half below. No magic numbers, no correction factors.

If it still looks off, the problem is the font metrics for that specific size, not the centering algorithm.

### Candidate Injection: Store Final Form, Don't Re-derive

When injecting variants (e.g., "it" + "IT"), don't store raw and re-apply transformations in `selectCandidate`. The transformation logic will override the user's explicit choice.

**Do this instead:** Store the exact form to commit as the "raw" value. For injected proper nouns, `raw = "IT"`. For normal candidates, `raw = "it"`. `selectCandidate` commits `rawWord` directly — no re-transformation.

```swift
// In updateCandidates:
pairs.append((raw: "it", display: "it"))       // lowercase variant
pairs.append((raw: "IT", display: "IT"))       // proper noun — raw IS the final form

// In selectCandidate:
// Just use rawWord, don't re-apply casing
```

### IMK Mouse Events: Wire the Callback

`CandidateView.onClicked` fires on click, but it calls `CandidateWindow.onCandidateSelected`. If nobody sets that callback, clicks silently do nothing.

**Do this in `activateServer`:**
```swift
candidateWindow.onCandidateSelected = { [weak self, weak client] index in
    self?.selectCandidate(at: index, client: client)
}
```

And clean up in `deactivateServer`:
```swift
candidateWindow.onCandidateSelected = nil
```

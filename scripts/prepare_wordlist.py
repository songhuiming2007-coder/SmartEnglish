#!/usr/bin/env python3
"""
下载 Peter Norvig 的词频表，清洗后生成 words.txt
来源：https://norvig.com/ngrams/count_1w.txt
格式：word\tfrequency（Tab 分隔，按频率降序）
"""

import urllib.request
import subprocess
import re
import os

URL = "https://norvig.com/ngrams/count_1w.txt"
OUTPUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Resources", "words.txt")
MAX_WORDS = 50000

def is_valid_word(word: str) -> bool:
    """只保留纯英文字母单词"""
    if not word.isalpha():
        return False
    if len(word) < 2 and word.lower() not in ('a', 'i'):
        return False
    if len(word) > 30:
        return False
    return True

def main():
    print(f"Downloading word frequency data from {URL}...")
    try:
        response = urllib.request.urlopen(URL)
        content = response.read().decode('utf-8')
    except Exception:
        print("urllib failed, falling back to curl...")
        content = subprocess.check_output(["curl", "-sL", URL]).decode('utf-8')

    print("Processing...")
    lines = content.strip().split('\n')
    words = []

    for line in lines:
        parts = line.split('\t')
        if len(parts) != 2:
            continue
        word, freq = parts[0].strip(), parts[1].strip()
        if not freq.isdigit():
            continue
        if is_valid_word(word):
            words.append((word.lower(), int(freq)))

    # 按频率降序排列
    words.sort(key=lambda x: x[1], reverse=True)

    # 去重（保留高频的）
    seen = set()
    unique_words = []
    for w, f in words:
        if w not in seen:
            seen.add(w)
            unique_words.append((w, f))

    # 取 Top N
    unique_words = unique_words[:MAX_WORDS]

    # 写入文件
    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    with open(OUTPUT, 'w', encoding='utf-8') as f:
        for word, freq in unique_words:
            f.write(f"{word}\t{freq}\n")

    print(f"Done! Wrote {len(unique_words)} words to {OUTPUT}")
    print(f"Top 10: {[w for w, _ in unique_words[:10]]}")

if __name__ == "__main__":
    main()

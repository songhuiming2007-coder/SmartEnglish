#!/usr/bin/env python3
"""
Download Norvig's 2-word frequency data and extract top bigrams.
Output: Resources/bigrams.txt with format "word1 word2\tfreq"
"""

import urllib.request
import os

URL = "https://norvig.com/ngrams/count_2w.txt"
OUTPUT = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "SmartEnglish", "Resources", "bigrams.txt"
)
MAX_BIGRAMS = 100000  # 取频率最高的 10 万个 bigram

def is_clean_bigram(w1, w2):
    return (w1.isalpha() and w2.isalpha() and
            len(w1) <= 20 and len(w2) <= 20)

def main():
    print(f"Downloading from {URL}...")
    response = urllib.request.urlopen(URL)
    content = response.read().decode('utf-8')

    bigrams = []
    for line in content.strip().split('\n'):
        parts = line.split('\t')
        if len(parts) != 2:
            continue
        words, freq_str = parts[0].strip(), parts[1].strip()
        word_parts = words.split(' ')
        if len(word_parts) != 2:
            continue
        w1, w2 = word_parts[0].lower(), word_parts[1].lower()
        if not is_clean_bigram(w1, w2):
            continue
        try:
            freq = int(freq_str)
        except ValueError:
            continue
        bigrams.append((w1, w2, freq))

    bigrams.sort(key=lambda x: x[2], reverse=True)
    bigrams = bigrams[:MAX_BIGRAMS]

    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    with open(OUTPUT, 'w', encoding='utf-8') as f:
        for w1, w2, freq in bigrams:
            f.write(f"{w1} {w2}\t{freq}\n")

    print(f"Wrote {len(bigrams)} bigrams to {OUTPUT}")

if __name__ == "__main__":
    main()

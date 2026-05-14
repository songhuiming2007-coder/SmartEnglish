.PHONY: generate build install dev clean uninstall log wordlist

PROJECT = SmartEnglish
SCHEME = SmartEnglish
CONFIG = Release

generate:
	xcodegen generate
	@echo "Xcode project generated"

wordlist:
	curl -sL "https://norvig.com/ngrams/count_1w.txt" | python3 -c "\
import sys, os; \
OUTPUT = 'SmartEnglishExtension/Resources/words.txt'; \
words = []; \
[words.append((l.strip().split('\t')[0].lower(), int(l.strip().split('\t')[1]))) \
 for l in sys.stdin if '\t' in l and l.strip().split('\t')[1].isdigit() \
 and l.strip().split('\t')[0].isalpha()]; \
words.sort(key=lambda x: x[1], reverse=True); \
seen = set(); unique = [(w,f) for w,f in words if w not in seen and not seen.add(w)][:50000]; \
os.makedirs(os.path.dirname(OUTPUT), exist_ok=True); \
open(OUTPUT,'w').write(''.join(f'{w}\t{f}\n' for w,f in unique)); \
print(f'Wrote {len(unique)} words')"

build:
	xcodebuild -project $(PROJECT).xcodeproj -scheme $(SCHEME) -configuration $(CONFIG) build
	@echo "Build succeeded"

install:
	@echo "Installing SmartEnglish..."
	@killall SmartEnglishExtension 2>/dev/null || true
	@killall SmartEnglish 2>/dev/null || true
	@sleep 0.5
	@rm -rf ~/Library/Input\ Methods/$(PROJECT).app
	@BUILD_DIR=$$(xcodebuild -project $(PROJECT).xcodeproj -scheme $(SCHEME) -configuration $(CONFIG) -showBuildSettings 2>/dev/null | grep -m1 'BUILT_PRODUCTS_DIR' | awk '{print $$3}'); \
	cp -R "$$BUILD_DIR/$(PROJECT).app" ~/Library/Input\ Methods/
	@echo "Installed to ~/Library/Input Methods/"
	@echo "First time: System Settings -> Keyboard -> Input Sources -> Add SmartEnglish"

dev: build install
	@echo "Dev cycle complete"

clean:
	xcodebuild -project $(PROJECT).xcodeproj -scheme $(SCHEME) clean 2>/dev/null || true
	rm -rf ~/Library/Developer/Xcode/DerivedData/$(PROJECT)-*
	@echo "Cleaned"

uninstall:
	killall SmartEnglishExtension 2>/dev/null || true
	killall SmartEnglish 2>/dev/null || true
	rm -rf ~/Library/Input\ Methods/$(PROJECT).app
	@echo "Uninstalled"

log:
	log stream --predicate 'process == "SmartEnglishExtension"' --level debug

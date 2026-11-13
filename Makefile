VERSION ?= 0.1.0
APP      = build/Penumbra.app
BIN      = .build/release/Penumbra
ZIP      = build/Penumbra-$(VERSION).zip

.PHONY: all build app install uninstall run release clean icon

all: app

build:
	swift build -c release

# Assemble the .app bundle and sign it with a stable local identity (see scripts/signing-identity.sh).
app: build
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp $(BIN) $(APP)/Contents/MacOS/Penumbra
	cp Resources/AppIcon.icns $(APP)/Contents/Resources/
	sed 's/__VERSION__/$(VERSION)/g' Resources/Info.plist > $(APP)/Contents/Info.plist
	codesign --force --sign "$$(sh scripts/signing-identity.sh)" $(APP)
	@echo "built $(APP)"

install: app
	-pkill -x Penumbra
	rm -rf /Applications/Penumbra.app
	cp -R $(APP) /Applications/
	open /Applications/Penumbra.app
	@echo "installed /Applications/Penumbra.app"

uninstall:
	-pkill -x Penumbra
	rm -rf /Applications/Penumbra.app
	@echo "removed. To also drop the permission: System Settings → Privacy & Security → Accessibility → Penumbra → −"

# Run from the terminal with logging (the terminal app needs Accessibility permission).
run: build
	$(BIN) --verbose

# Unsigned-by-Apple release archive for GitHub Releases (ad-hoc signed).
release: build
	rm -rf $(APP) $(ZIP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp $(BIN) $(APP)/Contents/MacOS/Penumbra
	cp Resources/AppIcon.icns $(APP)/Contents/Resources/
	sed 's/__VERSION__/$(VERSION)/g' Resources/Info.plist > $(APP)/Contents/Info.plist
	codesign --force --sign - $(APP)
	cd build && ditto -c -k --keepParent Penumbra.app Penumbra-$(VERSION).zip
	@echo "built $(ZIP)"

# Regenerate Resources/AppIcon.icns from Resources/AppIcon.svg
icon:
	swift scripts/make-icon.swift

clean:
	rm -rf .build build

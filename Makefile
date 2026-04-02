.PHONY: build test clean package sign notarize dmg release run

SCHEME = Nudgy
BUILD_DIR = .build/release
APP_NAME = Nudgy
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
VERSION ?= 0.1.0
DMG_NAME = $(APP_NAME)-$(VERSION).dmg

# Build release binary
build:
	swift build -c release

# Build debug binary
debug:
	swift build

# Run all tests
test:
	swift test

# Clean build artifacts
clean:
	swift package clean
	rm -rf $(BUILD_DIR)/*.app $(BUILD_DIR)/*.dmg

# Create .app bundle from Swift binary
package: build
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	mkdir -p $(APP_BUNDLE)/Contents/Resources
	cp $(BUILD_DIR)/Nudgy $(APP_BUNDLE)/Contents/MacOS/
	cp Info.plist $(APP_BUNDLE)/Contents/
	echo -n "APPL????" > $(APP_BUNDLE)/Contents/PkgInfo
	cp AppIcon.icns $(APP_BUNDLE)/Contents/Resources/AppIcon.icns
	-cp -r Sources/Nudgy/Resources/* $(APP_BUNDLE)/Contents/Resources/ 2>/dev/null

# Code sign (requires SIGNING_IDENTITY env var)
sign: package
	codesign --deep --force --options runtime \
		--sign "$(SIGNING_IDENTITY)" \
		--entitlements Entitlements.plist \
		$(APP_BUNDLE)
	codesign --verify --verbose $(APP_BUNDLE)

# Notarize with Apple (requires APPLE_ID, TEAM_ID, APP_PASSWORD env vars)
notarize: sign
	ditto -c -k --keepParent $(APP_BUNDLE) $(BUILD_DIR)/$(APP_NAME).zip
	xcrun notarytool submit $(BUILD_DIR)/$(APP_NAME).zip \
		--apple-id "$(APPLE_ID)" \
		--team-id "$(TEAM_ID)" \
		--password "$(APP_PASSWORD)" \
		--wait
	xcrun stapler staple $(APP_BUNDLE)

# Create DMG with drag-to-Applications
dmg: package
	rm -rf $(BUILD_DIR)/dmg-staging
	mkdir -p $(BUILD_DIR)/dmg-staging
	cp -r $(APP_BUNDLE) $(BUILD_DIR)/dmg-staging/
	ln -sf /Applications $(BUILD_DIR)/dmg-staging/Applications
	hdiutil create -volname "$(APP_NAME)" \
		-srcfolder $(BUILD_DIR)/dmg-staging \
		-ov -format UDBZ \
		$(BUILD_DIR)/$(DMG_NAME)
	rm -rf $(BUILD_DIR)/dmg-staging

# Run the app (debug build)
run: debug
	.build/debug/Nudgy

# Full release pipeline
release: test sign dmg
	@echo "Release $(VERSION) ready at $(BUILD_DIR)/$(DMG_NAME)"

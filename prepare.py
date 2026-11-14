import base64, os
os.makedirs("Resources", exist_ok=True)
for src, dst in (("icon57.b64", "Resources/icon.png"), ("icon114.b64", "Resources/icon@2x.png")):
    open(dst, "wb").write(base64.b64decode(open(src).read()))
PLIST = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Treble</string>
<key>CFBundleIdentifier</key><string>com.iulian.treble</string>
<key>CFBundleName</key><string>Treble</string>
<key>CFBundleDisplayName</key><string>Treble</string>
<key>CFBundleVersion</key><string>1.1.1</string>
<key>CFBundleShortVersionString</key><string>1.1.1</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
<key>CFBundleIconFiles</key><array><string>icon.png</string><string>icon@2x.png</string></array>
<key>CFBundleIcons</key><dict><key>CFBundlePrimaryIcon</key><dict>
<key>CFBundleIconFiles</key><array><string>icon.png</string><string>icon@2x.png</string></array>
<key>UIPrerenderedIcon</key><false/></dict></dict>
<key>UIPrerenderedIcon</key><false/>
<key>LSRequiresIPhoneOS</key><true/>
<key>MinimumOSVersion</key><string>6.0</string>
<key>UIDeviceFamily</key><array><integer>1</integer></array>
<key>UIRequiredDeviceCapabilities</key><array><string>armv7</string></array>
<key>UIBackgroundModes</key><array><string>audio</string></array>
<key>UIStatusBarStyle</key><string>UIStatusBarStyleDefault</string>
<key>UISupportedInterfaceOrientations</key><array><string>UIInterfaceOrientationPortrait</string></array>
</dict></plist>
"""
open("Resources/Info.plist", "w").write(PLIST)
for f in sorted(os.listdir("Resources")):
    print(f, os.path.getsize("Resources/" + f))

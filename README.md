# Treble (native, iPod touch 4 / iOS 6.1.6, jailbroken)

Objective-C / UIKit, built with Theos into a .deb that installs to /Applications/Treble.app.
Audio engine: ExtAudioFile -> 10-band EQ -> NewTimePitch (per-song speed) -> RemoteIO. Background audio, lock-screen / multitasking controls.

## Build (pick one)
A) GitHub Actions (no local setup): push this folder to a GitHub repo -> Actions tab -> download "Treble-deb".
B) Theos on Mac / Linux / WSL: install Theos + an iOS SDK, then `make package` -> packages/*.deb
   (if the SDK complains about armv7 or iOS 6, use an older SDK, e.g. 9.3, in the TARGET line of Makefile)

## Install
Copy the .deb to the iPod (iFile / Filza / SFTP) and open it, or: `dpkg -i com.iulian.treble_1.0.0_iphoneos-arm.deb` then `uicache`.

## Adding music (the "drag a folder from my PC" part)
Copy songs or folders to /var/mobile/Media/Treble/Inbox with SFTP (WinSCP), iFile, 3uTools or iFunBox.
Open Treble -> Create -> Scan Inbox. (Also scans on launch.)
Create tab toggle: "Folder = Playlist" makes one unnamed playlist per folder (name it later with Edit Details); "Songs Only" imports the songs without playlists.

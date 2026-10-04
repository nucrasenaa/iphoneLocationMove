# iPhone Location Move

A native SwiftUI and MapKit macOS location simulation tool. Connect an iOS 17+
iPhone over USB to set a single simulated location or move between two points
along a MapKit walking route. Routes support `1–7 km/h`, pause/resume, speed
changes, and optional round-trip looping.

Under the hood, the app uses the developer DVT `simulate-location` capability
from [`pymobiledevice3`](https://github.com/doronz88/pymobiledevice3). This is
Apple's official developer mechanism for testing location-aware apps and is at
the same level as Xcode location simulation. It does not jailbreak or modify
the iPhone system.

> **⚠️ Read the [Disclaimer](#disclaimer) before using this project.**

## Disclaimer

This project is intended **for software development, testing, and educational
purposes only**. By using this tool, you acknowledge and agree that:

- **Terms-of-service risk:** Simulating your location in third-party apps or
  services such as maps, social networks, games, check-in services, or delivery
  platforms may violate their Terms of Service and may result in warnings,
  feature restrictions, temporary suspension, or permanent account bans. You
  assume all such risks.
- **Legal responsibility:** You are solely responsible for ensuring that your
  use complies with all applicable laws and regulations in your jurisdiction.
  Do not use this tool for fraud, evading law enforcement, infringing on other
  people's rights, or any other unlawful purpose.
- **No evasion capability:** This project does not provide and will not provide
  anti-detection, anti-cheat evasion, or account-safety guarantees.
- **Device and system risk:** The tool requires macOS administrator permission
  to install a privileged helper and communicates with the iPhone through
  developer services. The authors have tried to minimize permissions, but
  cannot guarantee that unexpected behavior will not occur in every environment.
  After simulation ends, follow [Clear simulated location](#clear-simulated-location)
  to confirm that the iPhone has returned to its real location.
- **No warranty:** The software is provided **AS IS**, without warranties of
  any kind, express or implied, including but not limited to merchantability,
  fitness for a particular purpose, and non-infringement. In no event shall the
  authors or contributors be liable for any direct, indirect, incidental,
  consequential, or other damages arising from the use of or inability to use
  this software, including account loss, data loss, or device problems.

## Features

- Native SwiftUI + MapKit interface with place search and map selection.
- English is the default language. Use the globe menu in the window toolbar to
  switch between English and Thai; the selection is persisted for the next launch.
- Single-point simulation: search for a place or select a point on the map, then
  confirm and send the simulated location.
- A/B walking routes: MapKit generates a real walking route and moves along it
  at `1–7 km/h`, with pause, resume, speed control, and optional round-trip looping.
- Safe clearing flow: stopping simulation, quitting the app, and USB disconnect
  recovery all send a clear command to prevent a simulated location from being
  left behind.
- Minimal-privilege helper: only uses a fixed-version, embedded offline
  wheelhouse validated by the app's code signature and SHA-256 trust anchor; it
  does not install packages over the network.

## Requirements

To run the app:

- macOS 13 or later.
- An Apple Silicon Mac. The currently embedded privileged tunnel wheelhouse is
  arm64-only.
- An iOS 17 or later iPhone.
- A USB cable capable of data transfer.
- The iPhone must be unlocked, trust this Mac, and have Developer Mode enabled.
- Python 3.9 or later, or a compatible `pymobiledevice3` already available on
  `PATH`.

Additional requirements to build from source:

- Xcode signed in with an available Apple Development account.

To enable Developer Mode:

1. On the iPhone, open **Settings → Privacy & Security → Developer Mode**.
2. Turn it on and follow the instructions to restart the iPhone.
3. Unlock the iPhone again and confirm that Developer Mode is enabled.

## Download and install

Download the latest `iPhoneLocationMove-<version>.dmg` from
[Releases](https://github.com/cashwu/iphoneLocationMove/releases/latest).

1. Open the DMG and drag `iPhoneLocationMove.app` to `/Applications`.
2. The DMG is signed with an **Apple Development certificate but is not notarized
   by Apple**. Gatekeeper may block it after a browser download. Before the first
   launch, remove the quarantine attribute yourself if you have verified the
   source:

   ```sh
   xattr -dr com.apple.quarantine /Applications/iPhoneLocationMove.app
   ```

3. Open the app and follow [First launch](#first-launch) to install device
   support and authorize the helper.

> **⚠️ About the prebuilt DMG**
>
> - Because it is not notarized, macOS cannot verify the source and integrity of
>   the installer for you. Confirm that the DMG came from this repository's
>   Releases page before removing quarantine. Removing quarantine bypasses a
>   macOS source check; only do this for files whose source you trust.
> - This build includes `com.apple.security.get-task-allow` for development and
>   is not intended for large-scale distribution.
> - The app installs a privileged helper that runs as root. Read the
>   [Disclaimer](#disclaimer) and evaluate the risk before installation.
> - If you do not accept these limitations, use
>   [Build and run from Xcode](#build-and-run-from-xcode) and sign the app with
>   your own Apple Development Team.

## Build and run from Xcode

This project is built and run locally with an Apple Development certificate.
After forking or cloning, use your own Development Team:

1. Open `iPhoneLocationMove.xcodeproj`.
2. Select the `iPhoneLocationMove` scheme and the `My Mac` destination.
3. Select your own Team under **Signing & Capabilities**.
4. Update the Team ID in the following three places. The app and privileged
   helper authenticate each other through `SMJobBless`, so all three values must
   match:
   - `iPhoneLocationMove/project.yml` — `DEVELOPMENT_TEAM`
   - `iPhoneLocationMove/Info.plist` — `SMPrivilegedExecutables`
   - `iPhoneLocationMoveTunnelHelper/HelperInfo.plist` — `SMAuthorizedClients`
5. After changing `project.yml`, regenerate the project with XcodeGen:

   ```sh
   xcodegen generate \
     --spec iPhoneLocationMove/project.yml \
     --project . \
     --project-root .
   ```

6. Press Run (`⌘R`).

## First launch

1. Read and acknowledge the third-party service terms and account-risk warning.
2. The app checks whether a compatible `pymobiledevice3` is already available on
   `PATH`.
3. If it is not available, select **Install Device Support**. The app creates
   its own virtual environment using the existing Python installation and does
   not modify global Python or Homebrew.
4. Select **Authorize Helper** and complete the macOS administrator prompt. The
   app currently installs the minimal-privilege tunnel helper with `SMJobBless`.
5. Connect and unlock the iPhone over USB. If prompted on the iPhone, select
   **Trust This Computer**.
6. The app checks trust, Developer Mode, the Developer Disk Image, the tunnel,
   and the DVT session in order. The device is shown as ready only after all
   steps complete.

The app's user-level runtime is stored at:

```text
~/Library/Application Support/iPhoneLocationMove/DeviceRuntime/
```

The privileged helper does not install packages over the network. It only uses
the embedded, fixed-version offline wheelhouse validated by the code signature
and SHA-256 trust anchor, and installs it atomically at the pinned
`pymobiledevice3-11.13.0` location:

```text
/Library/Application Support/iPhoneLocationMove/TunnelRuntime/pymobiledevice3-11.13.0/
```

## Usage

### Single-point simulation

1. Search for a place or select a point on the map.
2. Confirm the preview coordinates.
3. Select **Set Location** and acknowledge the risk warning.

### A/B walking route

1. Select points A and B on the map.
2. Wait for MapKit to generate the walking route.
3. Choose a speed between `1–7 km/h`.
4. Optionally enable **Round Trip**.
5. Select **Start**. Without round-trip mode, the simulation stops at B.

During a simulation, you can pause, resume, or adjust the speed. A speed change
uses the last confirmed successful location as the new baseline and does not show
an unconfirmed tick as completed progress.

## Clear simulated location

Under normal conditions, use **Stop Simulation** in the app. The app stops the
location producer first, then sends a clear command to the iPhone. When the app
quits, it also clears the simulated location, closes the DVT helper, and stops
the tunnel before exiting.

If the USB connection is unexpectedly lost, reconnect the same iPhone and let the
app run recovery. It clears any possibly persisted simulated location before
resuming nothing; it does not automatically continue the previous route.

If the app terminated unexpectedly and recovery cannot complete, relaunch the app
and connect the same iPhone. If the location still cannot be cleared, manually
create a `pymobiledevice3` tunnel and run:

```sh
pymobiledevice3 developer dvt simulate-location clear \
  --rsd <TUNNEL_ADDRESS> <TUNNEL_PORT>
```

Do not assume that the iPhone has returned to its real location until the clear
command succeeds.

## Tests

macOS unit and integration tests:

```sh
xcodebuild test \
  -project iPhoneLocationMove.xcodeproj \
  -scheme iPhoneLocationMove \
  -destination 'platform=macOS'
```

Python DVT protocol tests:

```sh
python3 -m unittest discover -s iPhoneLocationMoveHelper/tests
```

These automated tests do not require a physical iPhone or root privileges.

## Local Release packaging

`Scripts/package-app.sh` is the local packaging entry point and can be run from
any current working directory. Before running it, make sure that:

- Xcode command line tools are installed.
- Xcode is signed in with the same Apple Development Team configured above.
- `python3` is available on `PATH` and can run the Python protocol tests above.

From the repository root, run the default workflow:

```sh
Scripts/package-app.sh
```

The script cleans `build/`, runs the Xcode tests, runs the Python tests, builds
the Release app, verifies the app and embedded helper signatures plus the
bidirectional `SMJobBless` requirements, and finally creates a DMG. It stops on
any required failure and does not claim completion.

Available option:

- `-h` / `--help` — show usage information.

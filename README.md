<img width="400" alt="radis-icon-lockup-dark_1" src="https://github.com/user-attachments/assets/28e457e9-cfea-4d92-9294-9c70db740023" />

# DIS Radio — IEEE 1278 Radio Communications Tool

A multi-platform desktop application for Windows and Linux implementing the IEEE 1278 DIS (Distributed Interactive Simulation) radio communications protocol. Written in Flutter/Dart with full DIS PDU encode/decode, real-time G.711 audio, and a dark military-themed interface.

---

## Features

- **IEEE 1278.1-2012 compliant** PDU support: Transmitter, Signal, Receiver, Intercom Signal, Intercom Control
- **Multiple simultaneous radios** — define and operate several radio entities on independent DIS networks
- **Intercom support** — IEEE 1278 intercom PDUs (types 31 & 32) with source channel filtering
- **Crypto-aware receiver logic** — four interoperability scenarios: Perfect Match, Crypto Mismatch, Plain Text Intrusion, Secure Leakage
- **Modulation-aware filtering** — Signal PDUs are rejected when modulation schemes do not match
- **Audio device selection** — independent input/output device per radio and intercom
- **Channel presets** — pre-planned frequency/channel tables with one-click assignment; import/export JSON
- **PTT / VOX / Latched** — manual push-to-talk, voice-activated transmit (configurable threshold + hang time), or latched transmit
- **Keyboard bindings** — bind any key combination per radio for PTT control
- **G.711 audio codec** — μ-law and A-law encode/decode; CVSD and 16-bit PCM also supported
- **DIS networking** — UDP unicast, broadcast, or multicast (per radio/intercom)
- **Duplicate ID detection** — visual warning when multiple radios or intercoms share the same Entity ID + Radio/Intercom ID
- **Dark military theme**

---

## Quick Start & Installation

### Option 1: Standalone Binary (Recommended)

**[Download the latest release](https://github.com/shprice/Radis/releases/latest)** and extract the zip for your platform.

#### Windows
Extract `dis-radio-windows.zip` and run `dis_radio.exe`.

#### Linux
Extract `dis-radio-linux.zip` and run `bundle/dis_radio`.

---

### Option 2: Running from Source

Requires [Flutter SDK](https://docs.flutter.dev/get-started/install) ≥ 3.10 with desktop support.

```bash
# Enable desktop targets (run once)
flutter config --enable-windows-desktop   # Windows
flutter config --enable-linux-desktop     # Linux

# Install dependencies
flutter pub get

# Run
flutter run -d windows   # Windows
flutter run -d linux     # Linux
```

---

## Building from Source

```bash
flutter build windows --release   # → build\windows\x64\runner\Release\
flutter build linux   --release   # → build/linux/x64/release/bundle/
```

---

## Architecture

```
lib/
├── dis/           IEEE 1278 PDU encode/decode + UDP networking
│   ├── transmitter_pdu.dart
│   ├── signal_pdu.dart
│   ├── receiver_pdu.dart
│   ├── intercom_signal_pdu.dart
│   ├── intercom_control_pdu.dart
│   ├── entity_state_pdu.dart
│   ├── entity_id.dart
│   ├── constants.dart
│   └── dis_network.dart
├── audio/         Device enumeration, capture/playback, G.711, CVSD, VOX
├── models/        RadioConfig, IntercomConfig, IntercomChannel, AppSettings
├── providers/     ChangeNotifier state: Radio, DIS, Audio, Settings
├── screens/       Home, RadioConfig, IntercomConfig, Channels, Settings
└── widgets/       RadioCard, IntercomCard, FrequencyDisplay, PttButton, LevelMeter
```

---

## DIS PDU Support

| PDU Type | Number | Direction | Notes |
|---|---|---|---|
| Transmitter | 25 | TX/RX | Frequency, modulation, crypto fields |
| Signal | 26 | TX/RX | G.711 / CVSD / PCM audio payload |
| Receiver | 27 | TX | State reporting |
| Intercom Signal | 31 | TX/RX | Audio with source channel filtering |
| Intercom Control | 32 | TX/RX | PTT state, channel assignment |

---

## Crypto / Modulation Interoperability

Signal PDUs are filtered per-radio using the full IEEE 1278.1 receiver model:

| Scenario | Local Crypto | Remote Crypto | Key Match | Result |
|---|---|---|---|---|
| Perfect Match | None | None | — | ✅ Clear audio |
| Perfect Match | Set | Set | ✅ Yes | ✅ Clear audio |
| Crypto Mismatch | Set | Set | ❌ No | 🔇 Muted |
| Plain Text Intrusion | None | Set | — | 🔇 Muted |
| Secure Leakage | Set | None | — | 📻 Raw noise |

Modulation type (spread spectrum, major, detail, radio system) must also match for a Signal PDU to be decoded.

---

## Network Configuration

Default: multicast `239.1.2.3:3000` — the commonly used DIS exercise group.
Each radio and intercom can be independently configured for unicast, broadcast, or multicast on any interface, port, or multicast group.

---

## Third-Party Libraries & Acknowledgements

DIS Radio incorporates the following third-party libraries:

- **[Flutter](https://flutter.dev/)** (BSD-style License) — UI framework by Google.
- **[flutter_soloud](https://github.com/alnitak/flutter_soloud)** (MIT License) — Flutter bindings for the SoLoud audio engine by alnitak.
- **[SoLoud](https://github.com/jarikomppa/soloud)** (MIT License) — C++ audio engine by Jari Komppa, used for real-time audio playback.
- **[record](https://github.com/llfbandit/record)** (MIT License) — Audio capture library for Flutter by llfbandit.
- **[provider](https://github.com/rrousselGit/provider)** (MIT License) — State management by Remi Rousselet.
- **[shared_preferences](https://github.com/flutter/packages/tree/main/packages/shared_preferences)** (BSD-style License) — Persistent key-value storage, Flutter team.
- **[uuid](https://github.com/Daegalus/dart-uuid)** (MIT License) — UUID generation for Dart.
- **[path_provider](https://github.com/flutter/packages/tree/main/packages/path_provider)** (BSD-style License) — File system path access, Flutter team.
- **[file_picker](https://github.com/miguelpruivo/flutter_file_picker)** (MIT License) — Native file picker by Miguel Ruivo.
- **[window_manager](https://github.com/leanflutter/window_manager)** (MIT License) — Desktop window control by LeanFlutter.

### Standards

- **IEEE 1278.1-2012** — *Distributed Interactive Simulation — Application Protocols* (IEEE Standard for DIS).
- **SISO-REF-010** — *Reference for Enumerations for Simulation Interoperability* (SISO).

---

## License

MIT — see [LICENSE](LICENSE).

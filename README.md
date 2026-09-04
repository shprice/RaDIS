<img width="400" alt="radis-icon-lockup-dark_1" src="https://github.com/user-attachments/assets/28e457e9-cfea-4d92-9294-9c70db740023" />

# DIS Radio — IEEE 1278 Radio Communications Tool

A multi-platform desktop application written using Flutter for Windows and Linux implementing the IEEE 1278 DIS (Distributed Interactive Simulation) radio communications protocol.

## Features

- **IEEE 1278.1-2012 compliant** PDU support: Transmitter, Signal, Receiver, Intercom Signal, Intercom Control
- **Multiple radios** — define and operate several radio entities simultaneously  
- **Intercom support** — IEEE 1278 intercom PDUs (types 31 & 32)
- **Audio device enumeration** — select input/output device per radio
- **Net plans** — pre-planned frequency tables with channel assignment; import/export JSON
- **Manual PTT** — click or bind any keyboard key per radio
- **VOX** — voice-activated transmit with configurable threshold and hang time
- **G.711 audio codec** — μ-law and A-law encode/decode
- **DIS networking** — UDP unicast, broadcast, or multicast
- **Dark military theme**

## Setup

### Prerequisites
- Flutter SDK ≥ 3.10 with Windows/Linux desktop support enabled
- Run `flutter config --enable-windows-desktop` or `flutter config --enable-linux-desktop`

### Install & Run
```bash
cd DISRadio

# Create platform shell files (run once)
flutter create --project-name dis_radio --platforms windows,linux .

# Install dependencies
flutter pub get

# Run on Windows
flutter run -d windows

# Run on Linux
flutter run -d linux
```

## Architecture

```
lib/
├── dis/           IEEE 1278 PDU encode/decode + UDP networking
├── audio/         Device enumeration, capture/playback, G.711, VOX
├── models/        RadioConfig, IntercomConfig, NetPlan, AppSettings
├── providers/     ChangeNotifier state: Radio, DIS, Audio, Settings
├── screens/       Home, RadioConfig, NetPlan, AudioDevices, Settings
└── widgets/       RadioCard, FrequencyDisplay, PttButton, LevelMeter
```

## DIS PDU Support

| PDU Type | Number | Direction |
|----------|--------|-----------|
| Transmitter | 25 | TX/RX |
| Signal | 26 | TX/RX |
| Receiver | 27 | TX |
| Intercom Signal | 31 | TX/RX |
| Intercom Control | 32 | TX/RX |

## Audio Encoding

Defaults to G.711 μ-law at 8 kHz (DIS standard). Configurable to A-law or 16-bit PCM.
Signal PDUs sent in 100 ms chunks (800 bytes μ-law).

## Network Configuration

Default: multicast to `239.1.2.3:3000` — the commonly used DIS multicast group.
Configurable to unicast or broadcast in Settings.

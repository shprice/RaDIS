enum TriggerMode {
  ptt,
  latchedPtt,
  vox;

  String get label {
    switch (this) {
      case ptt:
        return 'PTT';
      case latchedPtt:
        return 'LTCH';
      case vox:
        return 'VOX';
    }
  }

  String get fullName {
    switch (this) {
      case ptt:
        return 'Push-to-Talk';
      case latchedPtt:
        return 'Latched (Permanent Send)';
      case vox:
        return 'Voice Activated';
    }
  }
}

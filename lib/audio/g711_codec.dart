import 'dart:math' as math;
import 'dart:typed_data';

/// G.711 mu-law and A-law codec implementation per ITU-T G.711.
class G711Codec {
  static const int _bias = 0x84; // 132
  static const int _clip = 32767;

  static Uint8List encodeMulaw(Int16List pcm) {
    final out = Uint8List(pcm.length);
    for (int i = 0; i < pcm.length; i++) {
      out[i] = _encodeOneMulaw(pcm[i]);
    }
    return out;
  }

  static int _encodeOneMulaw(int sample) {
    final int sign = sample < 0 ? 0x80 : 0;
    if (sign != 0) sample = -sample;
    if (sample > _clip) sample = _clip;
    final int sv = sample + _bias;
    // floor(log2(sv)) - 7, clamped to [0,7] — matches G.711 segment lookup.
    // sv.bitLength == floor(log2(sv)) + 1 for positive sv.
    final int exponent = (sv.bitLength - 8).clamp(0, 7);
    final int mantissa = (sv >> (exponent + 3)) & 0xF;
    return (~(sign | (exponent << 4) | mantissa)) & 0xFF;
  }

  static Int16List decodeMulaw(Uint8List mulaw) {
    final out = Int16List(mulaw.length);
    for (int i = 0; i < mulaw.length; i++) {
      out[i] = _decodeOneMulaw(mulaw[i]);
    }
    return out;
  }

  static int _decodeOneMulaw(int ulaw) {
    ulaw = ~ulaw & 0xFF;
    int sign = ulaw & 0x80;
    int exponent = (ulaw >> 4) & 0x07;
    int mantissa = ulaw & 0x0F;
    int sample = ((mantissa << 3) | 0x84) << exponent;
    sample -= _bias;
    return sign != 0 ? -sample : sample;
  }

  // A-law encode/decode per ITU-T G.711
  static Uint8List encodeAlaw(Int16List pcm) {
    final out = Uint8List(pcm.length);
    for (int i = 0; i < pcm.length; i++) {
      out[i] = _encodeOneAlaw(pcm[i]);
    }
    return out;
  }

  static int _encodeOneAlaw(int pcmVal) {
    int sign;
    if (pcmVal >= 0) {
      sign = 0xD5;
    } else {
      sign = 0x55;
      pcmVal = -pcmVal - 1;
    }
    pcmVal >>= 3; // shift so max is 4095

    int alaw;
    if (pcmVal < 0x20) {
      alaw = pcmVal;
    } else {
      int exp = 1;
      while (pcmVal > (0x1F + (0x10 << exp))) {
        exp++;
        if (exp > 6) break;
      }
      alaw = ((exp << 4) | ((pcmVal >> exp) & 0x0F));
    }
    return (alaw ^ sign) & 0xFF;
  }

  static Int16List decodeAlaw(Uint8List alaw) {
    final out = Int16List(alaw.length);
    for (int i = 0; i < alaw.length; i++) {
      out[i] = _decodeOneAlaw(alaw[i]);
    }
    return out;
  }

  static int _decodeOneAlaw(int alaw) {
    alaw ^= 0x55;
    int sign = alaw & 0x80;
    int exp = (alaw >> 4) & 0x07;
    int mantissa = alaw & 0x0F;
    int pcmVal;
    if (exp == 0) {
      pcmVal = (mantissa << 1) | 1;
    } else {
      pcmVal = ((mantissa | 0x10) << exp) | (1 << (exp - 1));
    }
    pcmVal <<= 3;
    return sign != 0 ? pcmVal : -pcmVal;
  }

  /// Convert raw byte buffer (little-endian 16-bit PCM) to Int16List.
  static Int16List bytesToInt16(Uint8List bytes) {
    final bd = ByteData.sublistView(bytes);
    final samples = bytes.length ~/ 2;
    final out = Int16List(samples);
    for (int i = 0; i < samples; i++) {
      out[i] = bd.getInt16(i * 2, Endian.little);
    }
    return out;
  }

  /// Convert Int16List to raw bytes (little-endian).
  static Uint8List int16ToBytes(Int16List samples) {
    final bd = ByteData(samples.length * 2);
    for (int i = 0; i < samples.length; i++) {
      bd.setInt16(i * 2, samples[i], Endian.little);
    }
    return bd.buffer.asUint8List();
  }

  /// Build a WAV file header + PCM data for playback.
  static Uint8List wrapInWav(Uint8List pcmBytes, int sampleRate,
      {int channels = 1, int bitsPerSample = 16}) {
    final dataSize = pcmBytes.length;
    final header = ByteData(44);
    // RIFF chunk
    header.setUint8(0, 0x52); // R
    header.setUint8(1, 0x49); // I
    header.setUint8(2, 0x46); // F
    header.setUint8(3, 0x46); // F
    header.setUint32(4, 36 + dataSize, Endian.little);
    header.setUint8(8, 0x57);  // W
    header.setUint8(9, 0x41);  // A
    header.setUint8(10, 0x56); // V
    header.setUint8(11, 0x45); // E
    // fmt chunk
    header.setUint8(12, 0x66); // f
    header.setUint8(13, 0x6D); // m
    header.setUint8(14, 0x74); // t
    header.setUint8(15, 0x20); // ' '
    header.setUint32(16, 16, Endian.little); // chunk size
    header.setUint16(20, 1, Endian.little);  // PCM format
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    header.setUint32(28, byteRate, Endian.little);
    final blockAlign = channels * bitsPerSample ~/ 8;
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    // data chunk
    header.setUint8(36, 0x64); // d
    header.setUint8(37, 0x61); // a
    header.setUint8(38, 0x74); // t
    header.setUint8(39, 0x61); // a
    header.setUint32(40, dataSize, Endian.little);

    final result = Uint8List(44 + dataSize);
    result.setRange(0, 44, header.buffer.asUint8List());
    result.setRange(44, 44 + dataSize, pcmBytes);
    return result;
  }
}

/// Stateful CVSD (Continuously Variable Slope Delta) codec.
///
/// Parameters match DISLogger's encoder/decoder exactly:
///   DELTA_MIN=10/32768, DELTA_MAX=1280/32768, STEP_UP=2.0, STEP_DOWN=0.80,
///   3-bit run-length history, LEAK=0.9997, bits packed MSB-first.
///
/// One instance per source stream — state must persist across chunks.
class CvsdDecoder {
  static const double _deltaMin = 10 / 32768;
  static const double _deltaMax = 1280 / 32768;

  double _acc = 0;
  double _delta = _deltaMin;
  int _history = 0;

  /// Decode [data] (1 bit per CVSD sample, MSB-first packed) to 16-bit LE PCM.
  Uint8List decode(Uint8List data) {
    final numBits = data.length * 8;
    final bd = ByteData(numBits * 2);

    for (int i = 0; i < numBits; i++) {
      final bit = (data[i >> 3] >> (7 - (i & 7))) & 1;
      _history = ((_history << 1) | bit) & 0x07;
      if (_history == 0 || _history == 0x07) {
        _delta = math.min(_delta * 2.0, _deltaMax);
      } else {
        _delta = math.max(_delta * 0.80, _deltaMin);
      }
      _acc = _acc * 0.9997 + (bit == 1 ? _delta : -_delta);
      final sample = (_acc * 32767).round().clamp(-32767, 32767);
      bd.setInt16(i * 2, sample, Endian.little);
    }

    return bd.buffer.asUint8List();
  }
}

/// Stateful CVSD encoder. Parameters mirror [CvsdDecoder].
class CvsdEncoder {
  static const double _deltaMin = 10 / 32768;
  static const double _deltaMax = 1280 / 32768;

  double _acc = 0;
  double _delta = _deltaMin;
  int _history = 0;

  /// Encode 16-bit LE PCM [pcm] to CVSD bitstream (1 bit/sample, MSB-first packed).
  Uint8List encode(Int16List pcm) {
    final numBytes = (pcm.length + 7) ~/ 8;
    final out = Uint8List(numBytes);

    for (int i = 0; i < pcm.length; i++) {
      final target = pcm[i] / 32768.0;
      final bit = _acc < target ? 1 : 0;
      _history = ((_history << 1) | bit) & 0x07;
      if (_history == 0 || _history == 0x07) {
        _delta = math.min(_delta * 2.0, _deltaMax);
      } else {
        _delta = math.max(_delta * 0.80, _deltaMin);
      }
      _acc = _acc * 0.9997 + (bit == 1 ? _delta : -_delta);
      if (bit == 1) out[i >> 3] |= (1 << (7 - (i & 7)));
    }

    return out;
  }
}

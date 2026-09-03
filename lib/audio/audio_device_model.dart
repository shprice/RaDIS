class AudioDevice {
  final String id;
  final String name;
  final bool isInput;
  final bool isOutput;
  final int channels;
  final List<int> supportedSampleRates;

  const AudioDevice({
    required this.id,
    required this.name,
    required this.isInput,
    required this.isOutput,
    this.channels = 1,
    this.supportedSampleRates = const [8000, 16000, 44100, 48000],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isInput': isInput,
        'isOutput': isOutput,
        'channels': channels,
        'supportedSampleRates': supportedSampleRates,
      };

  factory AudioDevice.fromJson(Map<String, dynamic> json) => AudioDevice(
        id: json['id'] as String,
        name: json['name'] as String,
        isInput: json['isInput'] as bool,
        isOutput: json['isOutput'] as bool,
        channels: (json['channels'] as num?)?.toInt() ?? 1,
        supportedSampleRates: (json['supportedSampleRates'] as List?)
                ?.map((e) => (e as num).toInt())
                .toList() ??
            const [8000, 16000, 44100, 48000],
      );

  @override
  String toString() => name;

  static AudioDevice get defaultInput => const AudioDevice(
        id: 'default_input',
        name: 'Default Input',
        isInput: true,
        isOutput: false,
      );

  static AudioDevice get defaultOutput => const AudioDevice(
        id: 'default_output',
        name: 'Default Output',
        isInput: false,
        isOutput: true,
      );
}

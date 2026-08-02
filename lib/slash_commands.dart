import 'dart:math';

class SlashCommandResult {
  const SlashCommandResult({
    required this.message,
    required this.shouldSend,
    this.showHelp = false,
    this.shouldClearInput = false,
  });

  final String message;
  final bool shouldSend;
  final bool showHelp;
  final bool shouldClearInput;
}

class SlashCommandHelper {
  static SlashCommandResult process(String input, {required String username}) {
    final trimmed = input.trim();
    if (trimmed.isEmpty || !trimmed.startsWith('/')) {
      return SlashCommandResult(message: input, shouldSend: true);
    }

    final parts = trimmed.split(RegExp(r'\s+'));
    final cmd = parts.first.toLowerCase();
    final args = parts.length > 1 ? parts.sublist(1) : <String>[];

    switch (cmd) {
      case '/shrug':
        return const SlashCommandResult(message: '¯\\_(ツ)_/¯', shouldSend: true);
      case '/tableflip':
        return const SlashCommandResult(message: '(╯°□°）╯︵ ┻━┻', shouldSend: true);
      case '/unflip':
        return const SlashCommandResult(message: '┬─┬ ノ( ゜-゜ノ)', shouldSend: true);
      case '/me':
        final action = args.join(' ').trim();
        if (action.isEmpty) {
          return const SlashCommandResult(message: '', shouldSend: false, showHelp: true);
        }
        return SlashCommandResult(message: '*$username $action*', shouldSend: true);
      case '/roll':
        final spec = args.isNotEmpty ? args.first : '1d6';
        final match = RegExp(r'(?:(\d+)d)?(\d+)').firstMatch(spec);
        int times = 1;
        int sides = 6;
        if (match != null) {
          if ((match.group(1) ?? '').isNotEmpty) {
            times = int.tryParse(match.group(1)!) ?? 1;
          }
          sides = int.tryParse(match.group(2)!) ?? 6;
        }
        times = times.clamp(1, 100);
        sides = sides.clamp(2, 1000);
        final random = Random();
        final rolls = List.generate(times, (_) => random.nextInt(sides) + 1);
        final total = rolls.fold<int>(0, (a, b) => a + b);
        return SlashCommandResult(message: '$username rolled $total (${rolls.join(', ')})', shouldSend: true);
      case '/joke':
        final jokes = [
          'Why did the developer go broke? Because he used up all his cache.',
          'I told my computer I needed a break, and it said: "No problem — I’ll go to sleep."',
          'There are only 10 types of people in the world: those who understand binary, and those who don’t.',
        ];
        return SlashCommandResult(message: jokes[Random().nextInt(jokes.length)], shouldSend: true);
      case '/clear':
        return const SlashCommandResult(message: '', shouldSend: false, shouldClearInput: true);
      case '/help':
        return const SlashCommandResult(message: '', shouldSend: false, showHelp: true);
      default:
        return SlashCommandResult(message: input, shouldSend: true);
    }
  }
}

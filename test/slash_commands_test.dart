import 'package:flutter_test/flutter_test.dart';
import 'package:chat/slash_commands.dart';

void main() {
  test('transforms common slash commands', () {
    final shrug = SlashCommandHelper.process('/shrug', username: 'Ava');
    expect(shrug.shouldSend, isTrue);
    expect(shrug.message, '¯\\_(ツ)_/¯');

    final roll = SlashCommandHelper.process('/roll 2d6', username: 'Ava');
    expect(roll.shouldSend, isTrue);
    expect(roll.message, contains('rolled'));
    expect(roll.message, contains('('));
  });

  test('returns help and clear states for QoL commands', () {
    final help = SlashCommandHelper.process('/help', username: 'Ava');
    expect(help.shouldSend, isFalse);
    expect(help.showHelp, isTrue);

    final clear = SlashCommandHelper.process('/clear', username: 'Ava');
    expect(clear.shouldSend, isFalse);
    expect(clear.shouldClearInput, isTrue);
  });
}

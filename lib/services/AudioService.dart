import 'package:just_audio/just_audio.dart';

class AudioService {
  final player = AudioPlayer();

  Future<void> loadAudio() async {
    await player.setUrl(
      "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3"
    );
  }

  void play() => player.play();
  void pause() => player.pause();

  Stream<Duration> get positionStream => player.positionStream;
  Stream<Duration?> get durationStream => player.durationStream;

  void dispose() {
    player.dispose();
  }
}
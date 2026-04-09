import 'package:flutter/material.dart';
import 'package:fyproject/services/AudioService.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ListeningPractice extends StatefulWidget {
  const ListeningPractice({super.key});

  @override
  State<ListeningPractice> createState() => _ListeningPracticeState();
}

class _ListeningPracticeState extends State<ListeningPractice> {

  final audio = AudioService();

  int? q1;
  int? q2;
  bool showResult = false;
  int score = 0;

  bool isPlaying = false;
  double progress = 0;

  @override
  void initState() {
    super.initState();
    initAudio();
  }

  Future<void> initAudio() async {
    await audio.loadAudio();

    audio.positionStream.listen((pos) {
      final total = audio.player.duration?.inSeconds ?? 1;

      setState(() {
        progress = pos.inSeconds / total;
      });
    });
  }

  @override
  void dispose() {
    audio.dispose();
    super.dispose();
  }

  /// 🔥 SAVE TO FIREBASE
  Future<void> saveProgress(int score) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("listening_progress")
        .add({
      "score": score,
      "date": DateTime.now(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),

      appBar: AppBar(
        backgroundColor: const Color(0xFF2D5BFF),
        elevation: 0,
        title: const Text("Listening Practice"),
      ),

      body: SingleChildScrollView(
        child: Column(
          children: [

            /// 🔵 AUDIO CARD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2D5BFF), Color(0xFF4A79F6)],
                ),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  const Text(
                    "Section 1 - Social Context",
                    style: TextStyle(color: Colors.white70),
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.volume_up, color: Colors.white),
                      ),

                      const SizedBox(width: 12),

                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Audio Track 1",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                          Text(
                            "Conversation about a hotel booking",
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      )
                    ],
                  ),

                  const SizedBox(height: 20),

                  /// 🔥 PROGRESS BAR (REAL TIME)
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: FractionallySizedBox(
                      widthFactor: progress,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  /// 🔥 CONTROLS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [

                      IconButton(
                        onPressed: () {
                          audio.player.seek(
                            Duration(seconds: audio.player.position.inSeconds - 10),
                          );
                        },
                        icon: const Icon(Icons.replay_10, color: Colors.white),
                      ),

                      const SizedBox(width: 10),

                      GestureDetector(
                        onTap: () {
                          if (isPlaying) {
                            audio.pause();
                          } else {
                            audio.play();
                          }

                          setState(() {
                            isPlaying = !isPlaying;
                          });
                        },
                        child: CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.white,
                          child: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.blue,
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),

                      IconButton(
                        onPressed: () {
                          audio.player.seek(
                            Duration(seconds: audio.player.position.inSeconds + 10),
                          );
                        },
                        icon: const Icon(Icons.forward_10, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            /// QUESTIONS
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [

                  _questionTile(
                    number: 1,
                    title: "What is the main topic of the conversation?",
                    groupValue: q1,
                    onChanged: (v) => setState(() => q1 = v),
                    options: const ["Hotel Booking", "Flight", "Restaurant"],
                  ),

                  const SizedBox(height: 16),

                  _questionTile(
                    number: 2,
                    title: "Where does the speaker work?",
                    groupValue: q2,
                    onChanged: (v) => setState(() => q2 = v),
                    options: const ["Hotel", "Airport", "Office"],
                  ),

                  const SizedBox(height: 20),

                  /// 🔥 SUBMIT
                  Container(
                    height: 55,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6A5AE0), Color(0xFF9D6BFF)],
                      ),
                    ),
                    child: TextButton(
                      onPressed: () async {

                        score = 0;

                        if (q1 == 1) score++;
                        if (q2 == 1) score++;

                        await saveProgress(score);

                        setState(() {
                          showResult = true;
                        });
                      },
                      child: const Text(
                        "Submit Answers",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  if (showResult) ...[
                    const SizedBox(height: 20),
                    Text(
                      "Score: $score / 2",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  /// 🔹 QUESTION TILE
  Widget _questionTile({
    required int number,
    required String title,
    required List<String> options,
    required int? groupValue,
    required Function(int?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.green,
                child: Text("$number",
                    style: const TextStyle(color: Colors.white)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title)),
            ],
          ),

          const SizedBox(height: 10),

          ...List.generate(options.length, (index) {
            return RadioListTile(
              value: index + 1,
              groupValue: groupValue,
              onChanged: onChanged,
              title: Text(options[index]),
            );
          }),
        ],
      ),
    );
  }
}
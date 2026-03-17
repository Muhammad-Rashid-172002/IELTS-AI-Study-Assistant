import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;


import '../../../controller/feedback_controller/feedback_controller.dart';

class SpeakingPractice extends StatefulWidget {
  const SpeakingPractice({super.key});

  @override
  State<SpeakingPractice> createState() => _SpeakingPracticeState();
}

class _SpeakingPracticeState extends State<SpeakingPractice> {

  final feedbackController = Get.put(FeedbackController());

  final stt.SpeechToText speech = stt.SpeechToText();

  bool isListening = false;

  String transcript = "";

  String topic = "Describe your favorite place";

  final topics = [
    "Describe your favorite place",
    "Describe a memorable trip",
    "Describe your hometown",
    "Describe a favorite teacher"
  ];

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0xFFF4F7FB),

      appBar: _appBar(),

      body: SingleChildScrollView(

        padding: const EdgeInsets.all(18),

        child: Column(

          children: [

            _infoBanner(),

            const SizedBox(height:20),

            _topicSelector(),

            const SizedBox(height:20),

            _recordCard(),

            const SizedBox(height:26),

            _aiButton(),

            const SizedBox(height:20),

            _aiResult(),

          ],
        ),
      ),
    );
  }

  // ------------------------------------------------
  // APP BAR
  // ------------------------------------------------

  AppBar _appBar(){
    return AppBar(
      elevation:0,
      backgroundColor: Colors.white,
      toolbarHeight:72,
      automaticallyImplyLeading:false,

      title: Row(
        children: [

          GestureDetector(
            onTap:()=>Get.back(),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF3FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back,color: Colors.black87),
            ),
          ),

          const SizedBox(width:14),

          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.mic,color: Colors.deepPurple),
          ),

          const SizedBox(width:12),

          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "AI Speaking Practice",
                style: TextStyle(
                    fontSize:17,
                    fontWeight:FontWeight.w700,
                    color:Colors.black),
              ),
              Text(
                "IELTS Speaking Trainer",
                style: TextStyle(fontSize:12,color:Colors.black54),
              ),
            ],
          )
        ],
      ),
    );
  }

  // ------------------------------------------------
  // INFO
  // ------------------------------------------------

  Widget _infoBanner(){

    return Container(
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors:[Color(0xFFEDE7FF),Color(0xFFF6F3FF)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          left: BorderSide(color: Colors.deepPurple,width:4),
        ),
      ),

      child: const Row(
        children: [

          Icon(Icons.lightbulb_outline,color:Colors.deepPurple),

          SizedBox(width:12),

          Expanded(
            child: Text(
              "Choose a topic and speak for 1-2 minutes. AI will evaluate your speaking skills.",
              style: TextStyle(fontSize:14,height:1.4),
            ),
          )
        ],
      ),
    );
  }

  // ------------------------------------------------
  // TOPIC
  // ------------------------------------------------

  Widget _topicSelector(){

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _card(),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          const Text(
            "Speaking Topic",
            style: TextStyle(fontSize:15,fontWeight:FontWeight.w700),
          ),

          const SizedBox(height:12),

          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: topic,
              items: topics.map((e){
                return DropdownMenuItem(
                  value:e,
                  child: Text(e),
                );
              }).toList(),
              onChanged: (v){
                setState(()=>topic=v!);
              },
            ),
          )
        ],
      ),
    );
  }

  // ------------------------------------------------
  // RECORD
  // ------------------------------------------------

  Widget _recordCard(){

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _card(),

      child: Column(
        children: [

          const Text(
            "Your Speech",
            style: TextStyle(fontWeight: FontWeight.w700),
          ),

          const SizedBox(height:16),

          GestureDetector(
            onTap: _toggleListening,

            child: CircleAvatar(
              radius:40,
              backgroundColor:
              isListening ? Colors.red : Colors.deepPurple,

              child: Icon(
                isListening ? Icons.stop : Icons.mic,
                color: Colors.white,
                size:30,
              ),
            ),
          ),

          const SizedBox(height:16),

          Text(
            isListening ? "Listening..." : "Tap to start speaking",
            style: const TextStyle(fontSize:14),
          ),

          const SizedBox(height:16),

          if(transcript.isNotEmpty)
            Text(
              transcript,
              style: const TextStyle(fontSize:14,height:1.4),
            )
        ],
      ),
    );
  }

  // ------------------------------------------------
  // AI BUTTON
  // ------------------------------------------------

  Widget _aiButton(){

    return Obx((){

      return Container(
        height:54,
        width:double.infinity,

        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors:[Color(0xFF7B61FF),Color(0xFFB3A4FF)],
          ),
          borderRadius: BorderRadius.circular(14),
        ),

        child: TextButton.icon(

          onPressed: feedbackController.isLoading.value
              ? null
              : (){

            if(transcript.isEmpty){
              Get.snackbar("Error","Please speak first");
              return;
            }

            feedbackController.generateFeedback(
              transcript,
              "Speaking",
            );

          },

          icon: feedbackController.isLoading.value
              ? const SizedBox(
            width:20,
            height:20,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth:2,
            ),
          )
              : const Icon(Icons.analytics,color: Colors.white),

          label: Text(
            feedbackController.isLoading.value
                ? "Analyzing..."
                : "Analyze Speaking",

            style: const TextStyle(
                color:Colors.white,
                fontWeight:FontWeight.w700),
          ),
        ),
      );
    });
  }

  // ------------------------------------------------
  // RESULT
  // ------------------------------------------------

  Widget _aiResult(){

    return Obx((){

      if(feedbackController.feedback.isEmpty){
        return const SizedBox();
      }

      return Container(
        margin: const EdgeInsets.only(top:20),
        padding: const EdgeInsets.all(18),
        decoration: _card(),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const Text(
              "AI Speaking Feedback",
              style: TextStyle(
                  fontSize:16,
                  fontWeight:FontWeight.w700),
            ),

            const SizedBox(height:12),

            Text(
              feedbackController.feedback.value,
              style: const TextStyle(
                  fontSize:15,
                  height:1.5),
            )
          ],
        ),
      );
    });
  }

  // ------------------------------------------------
  // SPEECH FUNCTION
  // ------------------------------------------------

  void _toggleListening() async {

    if(!isListening){

      bool available = await speech.initialize();

      if(available){

        setState(()=>isListening=true);

        speech.listen(

          onResult:(result){

            setState(() {
              transcript = result.recognizedWords;
            });

          },
        );
      }

    }else{

      setState(()=>isListening=false);

      speech.stop();
    }
  }

  // ------------------------------------------------
  // UI
  // ------------------------------------------------

  BoxDecoration _card(){
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow:[
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius:12,
          offset: const Offset(0,4),
        )
      ],
    );
  }
}
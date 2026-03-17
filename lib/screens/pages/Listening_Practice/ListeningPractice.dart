import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ListeningPractice extends StatefulWidget {
  const ListeningPractice({super.key});

  @override
  State<ListeningPractice> createState() => _ListeningPracticeState();
}

class _ListeningPracticeState extends State<ListeningPractice> {

  int? q1;
  int? q2;
  int score = 0;
  bool showResult = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        toolbarHeight: 72,
        automaticallyImplyLeading: false,

        title: Row(
          children: [

            _roundButton(Icons.arrow_back, onTap: () => Navigator.pop(context)),

            const SizedBox(width: 14),

            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFF4A79F6).withOpacity(0.15),
              ),
              child: const Icon(Icons.headphones,color: Color(0xFF4A79F6)),
            ),

            const SizedBox(width: 12),

            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Listening Practice",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                Text(
                  "IELTS Listening Test",
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ],
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),

        child: Column(
          children: [

            _infoBanner(),

            const SizedBox(height: 22),

            _audioCard(),

            const SizedBox(height: 22),

            _questionCard(),

            const SizedBox(height: 22),

            _submitButton(),

            if(showResult)
              _resultCard(),

          ],
        ),
      ),
    );
  }

  // ------------------------------------------------
  // INFO BANNER
  // ------------------------------------------------

  Widget _infoBanner(){
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFFDDEBFF), Color(0xFFE9F3FF)],
        ),
        border: const Border(
          left: BorderSide(color: Colors.blue,width:4),
        ),
      ),
      child: const Row(
        children: [

          Icon(Icons.info_outline,color:Color(0xFF4A79F6)),

          SizedBox(width:12),

          Expanded(
            child: Text(
              "Listen carefully to the audio and answer the questions below.",
              style: TextStyle(fontSize:14,height:1.4),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------
  // AUDIO PLAYER CARD
  // ------------------------------------------------

  Widget _audioCard(){
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          const Text(
            "Audio Player",
            style: TextStyle(fontWeight:FontWeight.bold,fontSize:16),
          ),

          const SizedBox(height:12),

          Row(
            children: [

              IconButton(
                icon: const Icon(Icons.play_circle_fill,size:40,color:Color(0xFF4A79F6)),
                onPressed: (){
                  // play audio
                },
              ),

              const Text("Play Listening Audio"),

            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------
  // QUESTIONS
  // ------------------------------------------------

  Widget _questionCard(){
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          const Text(
            "Questions",
            style: TextStyle(fontSize:16,fontWeight:FontWeight.bold),
          ),

          const SizedBox(height:16),

          const Text("1. What is the main topic of the audio?"),

          RadioListTile(
            title: const Text("Technology"),
            value: 1,
            groupValue: q1,
            onChanged: (v){setState((){q1=v;});},
          ),

          RadioListTile(
            title: const Text("Education"),
            value: 2,
            groupValue: q1,
            onChanged: (v){setState((){q1=v;});},
          ),

          const SizedBox(height:12),

          const Text("2. Who is speaking in the recording?"),

          RadioListTile(
            title: const Text("Teacher"),
            value: 1,
            groupValue: q2,
            onChanged: (v){setState((){q2=v;});},
          ),

          RadioListTile(
            title: const Text("Student"),
            value: 2,
            groupValue: q2,
            onChanged: (v){setState((){q2=v;});},
          ),

        ],
      ),
    );
  }

  // ------------------------------------------------
  // SUBMIT BUTTON
  // ------------------------------------------------

  Widget _submitButton(){
    return Container(
      height:54,
      width:double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors:[Color(0xFF4A79F6),Color(0xFF8FB2FF)],
        ),
      ),
      child: TextButton(
        onPressed: (){

          score = 0;

          if(q1 == 2) score++;
          if(q2 == 1) score++;

          setState(() {
            showResult = true;
          });

        },
        child: const Text(
          "Submit Answers",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize:16,
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------
  // RESULT CARD
  // ------------------------------------------------

  Widget _resultCard(){
    return Container(
      margin: const EdgeInsets.only(top:22),
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        children: [

          const Text(
            "Your Score",
            style: TextStyle(fontSize:18,fontWeight:FontWeight.bold),
          ),

          const SizedBox(height:10),

          Text(
            "$score / 2",
            style: const TextStyle(
              fontSize:28,
              fontWeight:FontWeight.bold,
              color:Color(0xFF4A79F6),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------
  // COMMON UI
  // ------------------------------------------------

  Widget _roundButton(IconData icon,{VoidCallback? onTap}){
    return GestureDetector(
      onTap:onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF3FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon,color:Colors.black87),
      ),
    );
  }

  BoxDecoration _cardDecoration(){
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
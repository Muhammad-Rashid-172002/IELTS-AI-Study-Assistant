import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controller/feedback_controller/feedback_controller.dart';

class FullMockTest extends StatefulWidget {
  const FullMockTest({super.key});

  @override
  State<FullMockTest> createState() => _FullMockTestState();
}

class _FullMockTestState extends State<FullMockTest> {

  final feedbackController = Get.put(FeedbackController());

  final TextEditingController answerController = TextEditingController();

  int questionIndex = 0;

  List<String> questions = [];

  bool testStarted = false;

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0xFFF4F7FB),

      appBar: _appBar(),

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(18),
        
          child: Column(
        
            crossAxisAlignment: CrossAxisAlignment.start,
        
            children: [
        
              _infoBanner(),
        
              const SizedBox(height:20),
        
              if(!testStarted)
                _startTestButton(),
        
              if(testStarted)
                _questionCard(),
        
              const SizedBox(height:20),
        
              if(testStarted)
                _answerBox(),
        
              const SizedBox(height:20),
        
              if(testStarted)
                _nextButton(),
        
              const SizedBox(height:20),
        
              _aiResult()
        
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------
  // APP BAR
  // ------------------------------------------------

  AppBar _appBar(){

    return AppBar(
      automaticallyImplyActions: false,
      elevation:0,
      backgroundColor: Colors.white,
      toolbarHeight:72,

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
              color: Colors.orange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.quiz,color: Colors.orange),
          ),

          const SizedBox(width:12),

          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Text(
                "AI Full Mock Test",
                style: TextStyle(
                    fontSize:17,
                    fontWeight:FontWeight.w700),
              ),

              Text(
                "Simulate real IELTS exam",
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
          colors:[Color(0xFFFFF3E0),Color(0xFFFFF8ED)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          left: BorderSide(color: Colors.orange,width:4),
        ),
      ),

      child: const Row(
        children: [

          Icon(Icons.info_outline,color: Colors.orange),

          SizedBox(width:12),

          Expanded(
            child: Text(
              "Take a full IELTS style mock test. AI will evaluate your answers and estimate your band score.",
              style: TextStyle(fontSize:14,height:1.4),
            ),
          )

        ],
      ),
    );
  }

  // ------------------------------------------------
  // START TEST
  // ------------------------------------------------

  Widget _startTestButton(){

    return Container(
      height:54,
      width:double.infinity,

      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors:[Color(0xFFFF9800),Color(0xFFFFC107)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),

      child: TextButton(

        onPressed: (){

          setState(() {
            testStarted = true;
          });

          _generateQuestions();

        },

        child: const Text(
          "Start AI Mock Test",
          style: TextStyle(
              color:Colors.white,
              fontWeight:FontWeight.bold,
              fontSize:16),
        ),
      ),
    );
  }

  // ------------------------------------------------
  // QUESTION CARD
  // ------------------------------------------------

  Widget _questionCard(){

    if(questions.isEmpty){
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      padding: const EdgeInsets.all(18),

      decoration: _card(),

      child: Text(
        questions[questionIndex],
        style: const TextStyle(fontSize:16,fontWeight:FontWeight.w600),
      ),
    );
  }

  // ------------------------------------------------
  // ANSWER BOX
  // ------------------------------------------------

  Widget _answerBox(){

    return Container(
      padding: const EdgeInsets.all(18),

      decoration: _card(),

      child: TextField(

        controller: answerController,

        maxLines:6,

        decoration: const InputDecoration(
          hintText: "Write your answer here...",
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  // ------------------------------------------------
  // NEXT BUTTON
  // ------------------------------------------------

  Widget _nextButton(){

    return Container(
      height:54,
      width:double.infinity,

      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors:[Color(0xFFFF9800),Color(0xFFFFC107)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),

      child: TextButton(

        onPressed: (){

          if(questionIndex < questions.length - 1){

            setState(() {
              questionIndex++;
              answerController.clear();
            });

          }else{

            feedbackController.generateFeedback(
                answerController.text,
                "MockTest"
            );

          }

        },

        child: Text(
          questionIndex == questions.length - 1
              ? "Submit Test"
              : "Next Question",

          style: const TextStyle(
              color:Colors.white,
              fontWeight:FontWeight.bold),
        ),
      ),
    );
  }

  // ------------------------------------------------
  // AI RESULT
  // ------------------------------------------------

  Widget _aiResult(){

    return Obx((){

      if(feedbackController.feedback.isEmpty){
        return const SizedBox();
      }

      return Container(
        padding: const EdgeInsets.all(18),

        decoration: _card(),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            const Text(
              "AI Test Result",
              style: TextStyle(
                  fontSize:16,
                  fontWeight:FontWeight.bold),
            ),

            const SizedBox(height:10),

            Text(
              feedbackController.feedback.value,
              style: const TextStyle(
                fontSize:15,
                height:1.5,
              ),
            )

          ],
        ),
      );
    });
  }

  // ------------------------------------------------
  // GENERATE QUESTIONS (AI)
  // ------------------------------------------------

  void _generateQuestions(){

    questions = [

      "Describe a situation when you solved a problem.",
      "What are advantages of technology in education?",
      "Do you think online learning will replace schools?",
      "How can governments improve public transportation?"

    ];

  }

  // ------------------------------------------------
  // CARD
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
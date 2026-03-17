import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controller/feedback_controller/feedback_controller.dart';

class Vocabularybuilder extends StatefulWidget {
  const Vocabularybuilder({super.key});

  @override
  State<Vocabularybuilder> createState() => _VocabularybuilderState();
}

class _VocabularybuilderState extends State<Vocabularybuilder> {

  final TextEditingController topicController = TextEditingController();

  final feedbackController = Get.put(FeedbackController());

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0xFFF4F7FB),

      appBar: _appBar(),

      body: SingleChildScrollView(

        padding: const EdgeInsets.all(18),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            _infoBanner(),

            const SizedBox(height:20),

            _topicInput(),

            const SizedBox(height:20),

            _generateButton(),

            const SizedBox(height:20),

            _resultCard(),

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
              color: Colors.green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.auto_awesome,color: Colors.green),
          ),

          const SizedBox(width:12),

          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Text(
                "AI Vocabulary Builder",
                style: TextStyle(
                    fontSize:17,
                    fontWeight:FontWeight.w700,
                    color:Colors.black),
              ),

              Text(
                "IELTS Band 7+ Words",
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
          colors:[Color(0xFFE8F8EF),Color(0xFFF1FCF6)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          left: BorderSide(color: Colors.green,width:4),
        ),
      ),

      child: const Row(
        children: [

          Icon(Icons.lightbulb_outline,color: Colors.green),

          SizedBox(width:12),

          Expanded(
            child: Text(
              "Enter an IELTS topic and AI will generate advanced vocabulary with meanings and examples.",
              style: TextStyle(fontSize:14,height:1.4),
            ),
          )

        ],
      ),
    );
  }

  // ------------------------------------------------
  // TOPIC INPUT
  // ------------------------------------------------

  Widget _topicInput(){

    return Container(
      padding: const EdgeInsets.all(18),

      decoration: _card(),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          const Text(
            "IELTS Topic",
            style: TextStyle(
                fontSize:15,
                fontWeight:FontWeight.w700),
          ),

          const SizedBox(height:12),

          TextField(
            controller: topicController,

            decoration: const InputDecoration(
              hintText: "Example: Education, Environment, Technology",
              border: OutlineInputBorder(),
            ),
          )

        ],
      ),
    );
  }

  // ------------------------------------------------
  // GENERATE BUTTON
  // ------------------------------------------------

  Widget _generateButton(){

    return Obx((){

      return Container(

        height:54,
        width:double.infinity,

        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors:[Color(0xFF2ECC9A),Color(0xFF7FECC2)],
          ),
          borderRadius: BorderRadius.circular(14),
        ),

        child: TextButton.icon(

          onPressed: feedbackController.isLoading.value
              ? null
              : (){

            if(topicController.text.isEmpty){

              Get.snackbar(
                  "Error",
                  "Enter a topic first",
                  backgroundColor: Colors.red,
                  colorText: Colors.white
              );

              return;
            }

            feedbackController.generateFeedback(

              "Generate IELTS band 7+ vocabulary words with meaning and example for topic: ${topicController.text}",

              "Vocabulary",

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
              : const Icon(Icons.auto_awesome,color: Colors.white),

          label: Text(

            feedbackController.isLoading.value
                ? "Generating..."
                : "Generate Vocabulary",

            style: const TextStyle(
                color:Colors.white,
                fontWeight:FontWeight.bold),
          ),
        ),
      );
    });
  }

  // ------------------------------------------------
  // RESULT
  // ------------------------------------------------

  Widget _resultCard(){

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
              "AI Generated Vocabulary",
              style: TextStyle(
                  fontSize:16,
                  fontWeight:FontWeight.w700),
            ),

            const SizedBox(height:12),

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
  // CARD STYLE
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
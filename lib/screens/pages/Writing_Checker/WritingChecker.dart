import 'package:flutter/material.dart';
import 'package:get/get.dart';

class WritingChecker extends StatefulWidget {
  const WritingChecker({super.key});

  @override
  State<WritingChecker> createState() => _WritingCheckerState();
}

class _WritingCheckerState extends State<WritingChecker> {

  final TextEditingController _essayController = TextEditingController();

  String bandScore = "";
  String feedback = "";

  bool isLoading = false;

  int wordCount = 0;

  @override
  void initState() {
    super.initState();

    _essayController.addListener(() {
      setState(() {
        wordCount = _essayController.text.split(" ").length;
      });
    });
  }

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

            _essayInput(),

            const SizedBox(height:20),

            _checkButton(),

            const SizedBox(height:24),

            if(bandScore.isNotEmpty)
              _resultCard()

          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------
  // APP BAR
  // -----------------------------------------------------

  AppBar _appBar(){
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      toolbarHeight: 72,
      automaticallyImplyLeading: false,

      title: Row(
        children: [

          _roundButton(Icons.arrow_back,onTap:()=>Get.back()),

          const SizedBox(width:14),

          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFFFF9F43).withOpacity(0.15),
            ),
            child: const Icon(Icons.edit,color: Color(0xFFFF9F43)),
          ),

          const SizedBox(width:12),

          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Text(
                "Writing Task Checker",
                style: TextStyle(
                    fontSize:17,
                    fontWeight:FontWeight.w700,
                    color:Colors.black),
              ),

              Text(
                "AI Essay Evaluation",
                style: TextStyle(fontSize:12,color:Colors.black54),
              ),
            ],
          )
        ],
      ),
    );
  }

  // -----------------------------------------------------
  // INFO BANNER
  // -----------------------------------------------------

  Widget _infoBanner(){
    return Container(
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),

        gradient: const LinearGradient(
          colors:[Color(0xFFFFF1E6),Color(0xFFFFF6EE)],
        ),

        border: const Border(
          left: BorderSide(color: Color(0xFFFF9F43),width:4),
        ),
      ),

      child: const Row(
        children: [

          Icon(Icons.lightbulb_outline,color:Color(0xFFFF9F43)),

          SizedBox(width:12),

          Expanded(
            child: Text(
              "Write your IELTS essay below. AI will analyze grammar, vocabulary, coherence and give band score.",
              style: TextStyle(fontSize:14,height:1.4),
            ),
          )
        ],
      ),
    );
  }

  // -----------------------------------------------------
  // ESSAY INPUT
  // -----------------------------------------------------

  Widget _essayInput(){
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [

              const Text(
                "Your Essay",
                style: TextStyle(
                    fontSize:15,
                    fontWeight:FontWeight.w700),
              ),

              Text(
                "$wordCount words",
                style: const TextStyle(
                    fontSize:13,
                    color: Colors.black54),
              )
            ],
          ),

          const SizedBox(height:12),

          Container(
            height:220,

            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black12),
            ),

            child: TextField(
              controller: _essayController,
              maxLines: null,
              expands: true,

              decoration: const InputDecoration(
                hintText: "Write your IELTS essay here...",
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(14),
              ),
            ),
          )
        ],
      ),
    );
  }

  // -----------------------------------------------------
  // CHECK BUTTON
  // -----------------------------------------------------

  Widget _checkButton(){
    return Container(
      height:54,
      width:double.infinity,

      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),

        gradient: const LinearGradient(
          colors:[Color(0xFFFF9F43),Color(0xFFFFC37B)],
        ),
      ),

      child: TextButton.icon(

        onPressed: () async {

          if(_essayController.text.isEmpty){
            Get.snackbar("Error","Please write your essay first");
            return;
          }

          setState(() {
            isLoading = true;
          });

          await Future.delayed(const Duration(seconds:2));

          // FAKE AI RESULT
          setState(() {

            bandScore = "7.0";

            feedback =
            "Good vocabulary and grammar. Improve coherence and paragraph structure.";

            isLoading = false;
          });

        },

        icon: isLoading
            ? const SizedBox(
            width:22,
            height:22,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth:2,
            ))
            : const Icon(Icons.auto_fix_high,color:Colors.white),

        label: Text(
          isLoading ? "Analyzing..." : "Check Essay",
          style: const TextStyle(
              fontSize:16,
              fontWeight:FontWeight.w700,
              color:Colors.white),
        ),
      ),
    );
  }

  // -----------------------------------------------------
  // RESULT
  // -----------------------------------------------------

  Widget _resultCard(){
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          const Text(
            "AI Evaluation",
            style: TextStyle(
                fontSize:17,
                fontWeight:FontWeight.bold),
          ),

          const SizedBox(height:16),

          Row(
            children: [

              const Text(
                "Band Score:",
                style: TextStyle(
                    fontSize:15,
                    fontWeight:FontWeight.w600),
              ),

              const SizedBox(width:8),

              Text(
                bandScore,
                style: const TextStyle(
                    fontSize:18,
                    fontWeight:FontWeight.bold,
                    color: Color(0xFFFF9F43)),
              )
            ],
          ),

          const SizedBox(height:12),

          Text(
            feedback,
            style: const TextStyle(
              fontSize:14,
              height:1.4,
            ),
          )
        ],
      ),
    );
  }

  // -----------------------------------------------------
  // COMMON UI
  // -----------------------------------------------------

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
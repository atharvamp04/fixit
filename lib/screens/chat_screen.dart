import 'package:bubble/bubble.dart';
import 'package:dialogflow_flutter/googleAuth.dart';
import 'package:flutter/material.dart';
import 'package:dialogflow_flutter/dialogflowFlutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatBotScreen extends StatefulWidget {
  @override
  _ChatBotScreenState createState() => _ChatBotScreenState();
}

class _ChatBotScreenState extends State<ChatBotScreen> {
  final messageInsert = TextEditingController();
  List<Map<String, dynamic>> messages = [];

  void handleQuery(String query) async {
    try {
      AuthGoogle authGoogle = await AuthGoogle(fileJson: "assets/newagent-9aew-094a12e96d99.json").build();
      DialogFlow dialogflow = DialogFlow(authGoogle: authGoogle, language: "en");
      AIResponse aiResponse = await dialogflow.detectIntent(query);

      var responseList = aiResponse.getListMessage();
      if (responseList != null && responseList.isNotEmpty) {
        var messageData = responseList[0]["text"];
        if (messageData != null && messageData["text"] != null) {
          String message = messageData["text"][0].toString();
          setState(() {
            messages.insert(0, {"data": 0, "message": message});
          });

          // Extract the product name and check stock availability
          String productName = extractProductName(message);
          if (productName.isNotEmpty) {
            await fetchStockAvailability(productName);
          }
        } else {
          setState(() {
            messages.insert(0, {"data": 0, "message": "Sorry, I didn't understand that."});
          });
        }
      } else {
        setState(() {
          messages.insert(0, {"data": 0, "message": "No response from the bot."});
        });
      }
    } catch (e) {
      print("Error in handleQuery: $e");
      setState(() {
        messages.insert(0, {"data": 0, "message": "An error occurred. Please try again."});
      });
    }
  }

  String extractProductName(String message) {
    // Example of simple keyword extraction; this can be enhanced as needed
    List<String> productKeywords = ["laptop", "phone", "headphone"]; // Add all relevant product keywords
    for (String keyword in productKeywords) {
      if (message.toLowerCase().contains(keyword.toLowerCase())) {
        return keyword;
      }
    }
    return "";
  }

  Future<void> fetchStockAvailability(String productName) async {
    try {
      final response = await Supabase.instance.client
          .from('stock')
          .select('stock_quantity')
          .eq('product_name', productName)
          .single();

      if (response != null) {
        int stockQuantity = response['stock_quantity'] ?? 0;
        setState(() {
          messages.insert(0, {
            "data": 0,
            "message": "The stock for $productName is $stockQuantity units."
          });
        });
      } else {
        setState(() {
          messages.insert(0, {
            "data": 0,
            "message": "Sorry, we couldn't find stock information for $productName."
          });
        });
      }
    } catch (error) {
      print("Error fetching stock: $error");
      setState(() {
        messages.insert(0, {
          "data": 0,
          "message": "An error occurred while fetching stock information."
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: 70,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
        ),
        elevation: 10,
        title: Text("DialogFlow Chatbot"),
      ),
      body: Container(
        child: Column(
          children: <Widget>[
            Flexible(
              child: ListView.builder(
                reverse: true,
                itemCount: messages.length,
                itemBuilder: (context, index) => chat(messages[index]["message"].toString(), messages[index]["data"]),
              ),
            ),
            Divider(height: 6.0),
            Container(
              padding: EdgeInsets.only(left: 15.0, right: 15.0, bottom: 20),
              margin: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: <Widget>[
                  Flexible(
                    child: TextField(
                      controller: messageInsert,
                      decoration: InputDecoration.collapsed(
                          hintText: "Send your message", hintStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.0)),
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 4.0),
                    child: IconButton(
                      icon: Icon(
                        Icons.send,
                        size: 30.0,
                      ),
                      onPressed: () {
                        if (messageInsert.text.isEmpty) {
                          print("empty message");
                        } else {
                          setState(() {
                            messages.insert(0, {"data": 1, "message": messageInsert.text});
                          });
                          handleQuery(messageInsert.text);
                          messageInsert.clear();
                        }
                      },
                    ),
                  )
                ],
              ),
            ),
            SizedBox(height: 15.0)
          ],
        ),
      ),
    );
  }

  Widget chat(String message, int data) {
    return Padding(
      padding: EdgeInsets.all(10.0),
      child: Bubble(
        radius: Radius.circular(15.0),
        color: data == 0 ? Colors.blue : Colors.orangeAccent,
        elevation: 0.0,
        alignment: data == 0 ? Alignment.topLeft : Alignment.topRight,
        nip: data == 0 ? BubbleNip.leftBottom : BubbleNip.rightTop,
        child: Padding(
          padding: EdgeInsets.all(2.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(width: 10.0),
              Flexible(
                child: Text(
                  message,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

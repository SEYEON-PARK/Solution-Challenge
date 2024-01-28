import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mytodaysdiary/DB/TokenSave.dart';
import 'package:mytodaysdiary/DB/diaryProvider.dart';
import 'package:mytodaysdiary/MysettingViews/mySetting.dart';
import 'package:mytodaysdiary/diaryViews/calendar.dart';
import 'package:provider/provider.dart';

class SendDiaryScreen extends StatefulWidget {
  @override
  _SendDiaryScreenState createState() => _SendDiaryScreenState();
}

class _SendDiaryScreenState extends State<SendDiaryScreen> {
  late String shareDiary = '';
  late String emotion = '';
  late int id;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _sendDiaryController = TextEditingController();
  final TextEditingController _cheeringMessageController = TextEditingController();
  int _selectedIndex = 0;
  String selectedLanguage = 'en'; // 기본 언어 설정
  List<String> translationLanguages = ['en', 'ko', 'ja', 'zh', 'fr', 'es', 'de', 'it', 'th'];
  String result_cloud_google = '';

  late DiaryProvider diaryProvider; // 추가된 부분


  final List<Widget> _widgetOptions = <Widget>[
    Calendar(),
    MySetting(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => _widgetOptions[index]),
    );
  }

  void decodeToken(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      print('토큰 구조가 잘못되었습니다.');
      return;
    }

    final payload = parts[1];
    final decoded = json.decode(utf8.decode(base64Url.decode(base64Url.normalize(payload))));
    print('디코딩된 토큰 페이로드: $decoded');
  }

  //서버에서 다른 사용자의 공유일기를 받아옴
  Future<void> getDiary() async {
  final token = await TokenStorage.getToken();
  if (token != null) {
    decodeToken(token);

    try {
      final getResponse = await http.get(
        Uri.parse('http://localhost:8080/diary/oldest'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      print('Server Response: ${getResponse.statusCode}');
      print('Server Response Body: ${getResponse.body}');

      if (getResponse.statusCode == 200) {
        // 서버에서 JSON 형식으로 반환된 데이터를 파싱
        try {
          final dynamic jsonData = jsonDecode(getResponse.body);
          final emotion = jsonData['emotion']??'';
          final shareDiary = jsonData['shareDiary'] ??'';
          final id = jsonData['id'] ??'';
          setState(() {
            this.emotion = emotion;
            this.shareDiary = shareDiary;
            this.id = id;
            diaryProvider.id = id;
          });

          print('데이터 가져오기 성공: $emotion, $shareDiary,$id');
        } catch (e) {
          print('데이터 파싱 중 오류 발생: $e');
        }
      } else if (getResponse.statusCode == 401) {
        // 인증 실패 처리
      } else {
        print('데이터 로드 실패: ${getResponse.statusCode}');
      }
    } catch (error, stackTrace) {
      print('에러: $error');
      print('스택 트레이스: $stackTrace');
    }
  } else {
    print('토큰이 없습니다.');
  }
}

  //서버에 응원에 메시지를 보내고 보내는 동시에 서버에서 일기의 id값을 보냄
  Future<void> sendCheerServer() async {
    final diaryProvider = Provider.of<DiaryProvider>(context, listen: false);

    String? token = await TokenStorage.getToken();
    if (token != null) {
      decodeToken(token);

      try {
        final response = await http.post(
          Uri.parse('http://localhost:8080/diary/writeMessage/${diaryProvider.id}'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'id': diaryProvider.id,
            'cheeringMessage': diaryProvider.cheeringMessage,
          }),
        );

        print('응답: ${response.statusCode}');
        print('응답 본문: ${response.body}');

        if (response.statusCode == 200) {
          print('성공: ${response.body}');

          try {
            final responseData = jsonDecode(response.body);
            print('응답 본문 디코딩 결과: $responseData');
          } catch (error) {
            print('JSON 디코딩 에러: $error');
          }
        } else {
          print('상태 코드 ${response.statusCode}로 실패했습니다.');
        }
      } catch (error) {
        print('에러: $error');
      }
    } else {
      print("토큰이 없습니다");
    }
  }
  
  //번역
    Future<void> getTranslation_google_cloud_translation(String targetLanguage) async {
    var _baseUrl = 'https://translation.googleapis.com/language/translate/v2';
    var key = 'AIzaSyB6EHY71E1D1CVUVqy5DpDRJpzNiyaHCsk';
    var to = targetLanguage; // 선택한 언어로 설정
    var text = shareDiary;
    var response = await http.post(
      Uri.parse('$_baseUrl?target=$to&key=$key&q=$text'),
    );

    if (response.statusCode == 200) {
      var dataJson = jsonDecode(response.body);
      result_cloud_google =
          dataJson['data']['translations'][0]['translatedText'];

      // Show the translated text in a dialog
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Translated Text'),
            content: Text(result_cloud_google),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );
    } else {
      print(response.statusCode);
    }
  }

  @override
  void initState() {
    super.initState();
    getDiary();
    diaryProvider = Provider.of<DiaryProvider>(context, listen: false); // 추가된 부분
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<DiaryProvider>(context, listen: false);
    return Scaffold(
      backgroundColor: const Color(0xFFECF4D6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFECF4D6),
        title: const Text("Diary"),
        actions: <Widget>[],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Container(
              alignment: Alignment.center,
              width: 329,
              height: 575.11,
              decoration: ShapeDecoration(
                color: Color(0xFFB19470),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Container(
                alignment: Alignment.topLeft,
                width: 323,
                height: 545.11,
                decoration: ShapeDecoration(
                  color: Color(0xFFD0D4C7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Container(
                  alignment: Alignment.center,
                  width: 317,
                  height: 530.11,
                  decoration: ShapeDecoration(
                    color: Color(0xFFFAFFEC),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Container(
                    alignment: Alignment.centerRight,
                    width: 290,
                    height: 480,
                    decoration: ShapeDecoration(
                      color: Color(0xFFFFFFEC),
                      shape: RoundedRectangleBorder(
                        side: BorderSide(width: 1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      shadows: [
                        BoxShadow(
                          color: Color(0x3F000000),
                          blurRadius: 4,
                          offset: Offset(0, 4),
                          spreadRadius: 0,
                        )
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            "누군가의 하루가 도착했어요.",
                            style: TextStyle(
                              color: Color(0xFF76453B),
                              fontSize: 18,
                              fontFamily: 'Noto Sans',
                              fontWeight: FontWeight.w400,
                              height: 0,
                            ),
                          ),
                          Padding(padding: const EdgeInsets.symmetric(vertical: 10.0)),
                    Container(
                    alignment: Alignment.topLeft,
                    width: 250,
                    height: 200,
                    decoration: ShapeDecoration(
                      color: Color(0xFFFFFFEC),
                      shape: RoundedRectangleBorder(
                        side: BorderSide(width: 1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      shadows: [
                        BoxShadow(
                          color: Color(0x3F000000),
                          blurRadius: 4,
                          offset: Offset(0, 4),
                          spreadRadius: 0,
                        )
                      ],
                    ),
                    padding:  const EdgeInsets.symmetric(vertical: 20.0),
                      child: Text('emotion : ${emotion} \n'
                            '${shareDiary}',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                            ),
                          ),
                          ),
                          // TextField에 서버에서 받아온 sendDiary를 설정
                          SizedBox(
                          

                          ),
                          // 번역 언어 선택 드롭다운
                          DropdownButton<String>(
                            value: selectedLanguage,
                            items: translationLanguages.map((String language) {
                              return DropdownMenuItem<String>(
                                value: language,
                                child: Text(language),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  selectedLanguage = newValue;
                                });
                              }
                            },
                          ),
                          SizedBox(
                            child: ElevatedButton(
                              onPressed: () {
                                getTranslation_google_cloud_translation(selectedLanguage);
                              },
                              child: Text(
                                "Translation",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontFamily: 'Gowun Dodum',
                                  fontWeight: FontWeight.w400,
                                  height: 0,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                primary: Color(0x996B3A2F),
                                elevation: 4,
                              ),
                            ),
                          ),
                          Padding(padding: const EdgeInsets.symmetric(vertical: 10.0)),
                          Text(
                            "A message of support that I would like to convey",
                            style: TextStyle(
                              color: Color(0xFF76453B),
                              fontSize: 18,
                              fontFamily: 'Noto Sans',
                              fontWeight: FontWeight.w400,
                              height: 0,
                            ),
                          ),
                          Padding(padding: const EdgeInsets.symmetric(vertical: 10.0)),
                          Form(
                          key: _formKey,
                          child:SizedBox(
                            width: 350,
                            child: TextFormField(
                              controller: _cheeringMessageController,
                              maxLines: null,
                              keyboardType: TextInputType.multiline,
                              decoration: InputDecoration(
                                hintText: 'Message',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return ("Please enter");
                                }
                                return null;
                              },
                            ),
                          ),
                          ),
                          Padding(padding: const EdgeInsets.symmetric(vertical: 30.0)),
                          ElevatedButton(
                            onPressed: () {
                              
                                userProvider.cheeringMessage = _cheeringMessageController.text;
                              sendCheerServer();
                              Navigator.of(context).push(MaterialPageRoute(builder: (_) => Calendar()));
                              
                            },
                            child: Text(
                              "Send",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontFamily: 'Gowun Dodum',
                                fontWeight: FontWeight.w400,
                                height: 0,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              primary: Color(0x996B3A2F),
                              elevation: 4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF9AD0C2),
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'My'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.white,
        onTap: _onItemTapped,
      ),
    );
  }
}

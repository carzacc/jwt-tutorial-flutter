import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert' show json, base64, ascii;

const SERVER_IP = 'http://27706f93.ngrok.io';
final storage = FlutterSecureStorage();

void main()  {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  Future<String> get jwtOrEmpty async {
    var jwt = await storage.read(key: "jwt");
    if (jwt == null) return "";
    return jwt;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Authentication Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: FutureBuilder(
          future: jwtOrEmpty,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return CircularProgressIndicator();
            if (snapshot.data != "") {
              var str = snapshot.data;
              var jwt = str.split(".");

              if (jwt.length != 3) {
                return LoginPage();
              } else {
                var payload = json.decode(
                    ascii.decode(base64.decode(base64.normalize(jwt[1]))));
                if (DateTime.fromMillisecondsSinceEpoch(payload["exp"] * 1000)
                    .isAfter(DateTime.now())) {
                  return HomePage(str, payload);
                } else {
                  return LoginPage();
                }
              }
            } else {
              return LoginPage();
            }
          }),
    );
  }
}

class LoginPage extends StatelessWidget {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void displayDialog(context, title, text) => showDialog(
        context: context,
        builder: (context) =>
            AlertDialog(title: Text(title), content: Text(text)),
      );

  Future<String> attemptLogIn(String username, String password) async {
    var res = await http.post("$SERVER_IP/login",
        body: {"username": username, "password": password});
    if (res.statusCode == 200) return res.body;
    return null;
  }

  Future<int> attemptSignUp(String username, String password) async {
    var res = await http.post('$SERVER_IP/signup',
        body: {"username": username, "password": password});
    return res.statusCode;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Log In"),
        ),
        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: <Widget>[
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(labelText: 'Username'),
              ),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(labelText: 'Password'),
              ),
              FlatButton(
                  onPressed: () async {
                    var username = _usernameController.text;
                    var password = _passwordController.text;
                    var jwt = await attemptLogIn(username, password);
                    if (jwt != null) {
                      storage.write(key: "jwt", value: jwt);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => HomePage.fromBase64(jwt)));
                    } else {
                      displayDialog(context, "An Error Occurred",
                          "No account was found matching that username and password");
                    }
                  },
                  child: Text("Log In")),
              FlatButton(
                  onPressed: () async {
                    var username = _usernameController.text;
                    var password = _passwordController.text;

                    if (username.length < 4)
                      displayDialog(context, "Invalid Username",
                          "The username should be at least 4 characters long");
                    else if (password.length < 4)
                      displayDialog(context, "Invalid Password",
                          "The password should be at least 4 characters long");
                    else {
                      var res = await attemptSignUp(username, password);
                      if (res == 201)
                        displayDialog(context, "Success",
                            "The user was created. Log in now.");
                      else if (res == 409)
                        displayDialog(
                            context,
                            "That username is already registered",
                            "Please try to sign up using another username or log in if you already have an account.");
                      else {
                        displayDialog(
                            context, "Error", "An unknown error occurred.");
                      }
                    }
                  },
                  child: Text("Sign Up"))
            ],
          ),
        ));
  }
}

class HomePage extends StatelessWidget {
  HomePage(this.jwt, this.payload);

  factory HomePage.fromBase64(String jwt) => HomePage(
      jwt,
      json.decode(
          ascii.decode(base64.decode(base64.normalize(jwt.split(".")[1])))));

  final String jwt;
  final Map<String, dynamic> payload;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text("Secret Data Screen")),
        body: Center(
          child: FutureBuilder(
              future:
                  http.read('$SERVER_IP/data', headers: {"Authorization": jwt}),
              builder: (context, snapshot) => snapshot.hasData
                  ? Column(
                      children: <Widget>[
                        Text("${payload['username']}, here's the data:"),
                        Text(snapshot.data,
                            style: Theme.of(context).textTheme.display1),
                        RaisedButton(
                          child: Text('Reload'),
                          onPressed: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        HomePage.fromBase64(jwt)));
                          },
                        ),
                        RaisedButton(
                          child: Text('Delete Key and BackToLogin'),
                          onPressed: () async {
                            await storage.deleteAll();
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => LoginPage()));
                          },
                        ),
                      ],
                    )
                  : snapshot.hasError
                      ? Text("An error occurred")
                      : CircularProgressIndicator()),
        ),
      );
}

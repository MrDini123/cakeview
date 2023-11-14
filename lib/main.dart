/*  CakeView
    Copyright (C) 2023 MrDini123

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published
    by the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_cookie_manager/webview_cookie_manager.dart';

void main() {
  runApp(MaterialApp(
    home: const WebViewApp(),
    themeMode: ThemeMode.system,
    theme: ThemeData(
      primarySwatch: Colors.lightBlue,
    ),
  ));
}

class WebViewApp extends StatefulWidget {
  const WebViewApp({Key? key}) : super(key: key);

  @override
  WebViewAppState createState() => WebViewAppState();
}

class WebViewAppState extends State<WebViewApp> {
  late WebViewController _controller;
  String currentServerIp = '';
  late String currentUrl;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted);
  }

  void tryToExtractCookies() async {
    final cookieManager = WebviewCookieManager();
    final cookies = await cookieManager.getCookies(currentUrl);
    final cfClearanceCookie = cookies.firstWhere(
      (cookie) => cookie.name == 'cf_clearance',
      orElse: () => Cookie('cf_clearance', 'not found'),
    );
    final userAgent = await _controller.getUserAgent();
    if (cfClearanceCookie.value == 'not found') {
      Future.microtask(() => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('cf_clearance cookie not found'),
            ),
          ));
      return;
    }
    final url = Uri.parse('$currentServerIp/post_captcha');
    final body = {
      'url': currentUrl,
      'user_agent': userAgent,
      'cookie': cfClearanceCookie.value,
    };
    final response = await HttpClient()
        .postUrl(url)
        .timeout(const Duration(seconds: 5))
        .then((request) {
      request.headers.add('content-type', 'application/x-www-form-urlencoded');
      request.write(Uri(queryParameters: body).query);
      return request.close();
    }, onError: (e) {
      Future.microtask(() => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
            ),
          ));
    });
    final responseBody = await response.transform(utf8.decoder).join();
    Future.microtask(() => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(responseBody),
          ),
        ));
  }

  void tryToInitView() async {
    final ipController = TextEditingController();
    await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter IP of server'),
        content: TextField(
          decoration: const InputDecoration(hintText: '192.168.1.2'),
          controller: ipController,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final enteredIP = ipController.text;
              if (enteredIP.isNotEmpty) {
                setState(() {
                  currentServerIp = 'http://$enteredIP:34332';
                });
                Navigator.of(context).pop();
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (currentServerIp.isNotEmpty) {
      final url = Uri.parse('$currentServerIp/url');
      final response = await HttpClient()
          .getUrl(url)
          .timeout(const Duration(seconds: 5))
          .then((request) {
        request.headers.add('user-agent', 'cakeview');
        return request.close();
      }, onError: (e) {
        setState(() {
          currentServerIp = '';
        });
        Future.microtask(() => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: $e'),
              ),
            ));
      });
      final responseBody = await response.transform(utf8.decoder).join();
      await _controller.loadRequest(Uri.parse(responseBody));
      setState(() {
        currentUrl = responseBody;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CakeView demo'),
        actions: <Widget>[
          IconButton(
              icon: const Icon(Icons.computer), onPressed: tryToInitView),
          IconButton(
            icon: const Icon(Icons.cookie),
            onPressed: currentServerIp.isNotEmpty ? tryToExtractCookies : null,
            color: currentServerIp.isNotEmpty ? null : Colors.grey,
          ),
        ],
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}

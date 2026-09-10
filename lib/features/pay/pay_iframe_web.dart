// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:oons/features/client/client_chrome.dart';

Widget buildPayIframe(String url) {
  final viewType = 'oons-pay-iframe-${url.hashCode}';
  // ignore: undefined_prefixed_name
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final iframe = html.IFrameElement()
      ..src = url
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..allow = 'payment *'
      ..allowFullscreen = true;
    return iframe;
  });
  return Container(
    decoration: BoxDecoration(
      color: Client.card,
      border: Border.all(color: Client.ink, width: Client.rule),
    ),
    clipBehavior: Clip.hardEdge,
    child: HtmlElementView(viewType: viewType),
  );
}

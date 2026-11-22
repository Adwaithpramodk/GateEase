import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:gateeaseapp/api_config.dart';

class PrivateImage extends StatefulWidget {
  const PrivateImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit,
    required this.errorBuilder,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final ImageErrorWidgetBuilder errorBuilder;

  @override
  State<PrivateImage> createState() => _PrivateImageState();
}

class _PrivateImageState extends State<PrivateImage> {
  late Future<Uint8List> _bytes = _load();

  Future<Uint8List> _load() async {
    final uri = Uri.parse(baseurl).resolve(widget.url);
    if (!isGateEaseOrigin(uri) || !uri.path.startsWith('/media/')) {
      throw const FormatException('Invalid private image URL');
    }
    final response = await dio.getUri<Uint8List>(
      uri,
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data!;
  }

  @override
  void didUpdateWidget(PrivateImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _bytes = _load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return widget.errorBuilder(
            context,
            snapshot.error!,
            snapshot.stackTrace,
          );
        }
        if (!snapshot.hasData) {
          return SizedBox(width: widget.width, height: widget.height);
        }
        return Image.memory(
          snapshot.data!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          errorBuilder: widget.errorBuilder,
        );
      },
    );
  }
}

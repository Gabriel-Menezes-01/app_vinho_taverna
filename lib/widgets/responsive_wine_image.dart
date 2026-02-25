import 'dart:io';
import 'package:flutter/material.dart';

class ResponsiveWineImage extends StatelessWidget {
  final String? imagePath;
  final String? imageUrl;
  final double width;
  final double height;
  final double borderRadius;
  final BoxFit fit;
  final bool enablePreview;
  final String? heroTag;

  const ResponsiveWineImage({
    super.key,
    required this.imagePath,
    this.imageUrl,
    required this.width,
    required this.height,
    this.borderRadius = 0,
    this.fit = BoxFit.contain,
    this.enablePreview = false,
    this.heroTag,
  });

  void _showPreview(BuildContext context) {
    final hasNetwork = imageUrl != null && imageUrl!.isNotEmpty;
    final hasLocal = imagePath != null && imagePath!.isNotEmpty;
    if (!hasNetwork && !hasLocal) return;

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          backgroundColor: Colors.black,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: hasNetwork
                  ? Image.network(
                      imageUrl!,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(
                            Icons.wine_bar,
                            size: 100,
                            color: Colors.white70,
                          ),
                        );
                      },
                    )
                  : Image.file(
                      File(imagePath!),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(
                            Icons.wine_bar,
                            size: 100,
                            color: Colors.white70,
                          ),
                        );
                      },
                    ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = Center(
      child: Icon(
        Icons.wine_bar,
        size: 50,
        color: Colors.grey[400],
      ),
    );

    final hasNetwork = imageUrl != null && imageUrl!.isNotEmpty;
    final hasLocal = imagePath != null && imagePath!.isNotEmpty;
    final imageWidget = hasNetwork
        ? Image.network(
            imageUrl!,
            fit: fit,
            errorBuilder: (context, error, stackTrace) => placeholder,
          )
        : hasLocal
            ? Image.file(
                File(imagePath!),
                fit: fit,
                errorBuilder: (context, error, stackTrace) => placeholder,
              )
            : placeholder;

    final content = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: ColoredBox(
        color: Colors.grey[200]!,
        child: SizedBox(
          width: width,
          height: height,
          child: imageWidget,
        ),
      ),
    );

    final tappable = enablePreview && (hasNetwork || hasLocal)
        ? GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _showPreview(context),
            child: content,
          )
        : content;

    if (heroTag == null) return tappable;

    return Hero(
      tag: heroTag!,
      child: tappable,
    );
  }
}

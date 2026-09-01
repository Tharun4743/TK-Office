import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/presentation_model.dart';

class PresentationModeScreen extends StatefulWidget {
  final PresentationModel presentation;
  final int initialSlideIndex;

  const PresentationModeScreen({
    super.key,
    required this.presentation,
    this.initialSlideIndex = 0,
  });

  @override
  State<PresentationModeScreen> createState() => _PresentationModeScreenState();
}

class _PresentationModeScreenState extends State<PresentationModeScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialSlideIndex;
    _pageController = PageController(initialPage: _currentIndex);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pageController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slides = widget.presentation.slides;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemCount: slides.length,
            itemBuilder: (context, index) {
              final slide = slides[index];
              return Center(
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: slide.backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      children: slide.elements.map((elem) {
                        return Positioned(
                          left: elem.x,
                          top: elem.y,
                          width: elem.width,
                          height: elem.height,
                          child: elem.type == SlideElementType.text
                              ? Text(
                                  elem.content,
                                  style: TextStyle(
                                    fontSize: elem.fontSize,
                                    fontWeight: elem.isBold ? FontWeight.bold : FontWeight.normal,
                                    fontStyle: elem.isItalic ? FontStyle.italic : FontStyle.normal,
                                    color: elem.textColor,
                                  ),
                                  textAlign: elem.align,
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    color: elem.fillColor ?? Colors.orange.withAlpha(80),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              );
            },
          ),

          // Exit & Navigation Controls Overlay
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton.filledTonal(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / ${slides.length}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

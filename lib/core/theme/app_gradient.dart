import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppGradient {
  static LinearGradient darkGreenLinear() => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      const Color(0xFF021B16), // dark
      AppColors.primary, // primary
      AppColors.primary, // primary
      const Color(0xFF021B16), //
    ],
  );

  static LinearGradient greyLinear() => const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF3F4F6), Color(0xFFE5E7EB)],
  );

  static RadialGradient darkGreenRadial() => RadialGradient(
    center: Alignment.topCenter,
    radius: 1.6,
    colors: [
      AppColors.primary, // bright green (top glow)
      const Color(0xFF06352B), // mid blend
      const Color(0xFF021B16), // dark edges
    ],
    stops: const [0.0, 0.45, 1.0],
  );

  //Gradient List
  static List<Color> blueMyAppGradient = const [
    Color.fromARGB(255, 15, 97, 164),
    Color.fromARGB(206, 36, 129, 195),
    Color.fromARGB(184, 5, 145, 226),
  ];
  static List<Color> purpleMyAppGradient = const [
    Color.fromARGB(255, 181, 126, 220),
    Color.fromARGB(219, 183, 71, 203),
    Color.fromARGB(209, 115, 47, 155),
  ];
  static List<Color> orangeMyAppGradient = const [
    Color.fromARGB(255, 197, 130, 60),
    Color.fromARGB(255, 204, 147, 95),
    Color.fromARGB(255, 197, 130, 60),
  ];
  static List<Color> skyBlueMyAppGradient = const [
    Color.fromRGBO(37, 146, 166, 1),
    Color.fromRGBO(92, 182, 197, 1),
    Color.fromRGBO(37, 146, 166, 1),
  ];

  static List<Color> darkBlueGradient = const [
    Color.fromARGB(255, 32, 38, 157),
    Color.fromARGB(255, 34, 95, 216),
    Color.fromARGB(255, 32, 38, 157),
  ];

  static List<Color> youtubeGradient = const [
    Color.fromARGB(255, 255, 0, 0),
    Color.fromARGB(255, 230, 0, 0),
    Color.fromARGB(255, 179, 0, 0),
  ];

  static List<Color> greenGradient = [
    const Color(0xff49ad4d),
    Colors.green.shade400,
    const Color(0xff66af66),
  ];

  static List<Color> skyBlueGradient = [
    Colors.blue,
    Colors.blueAccent.shade400,
  ];

  static List<Color> instagramGradient = const [
    Color.fromARGB(255, 193, 53, 132),
    Color.fromARGB(255, 255, 105, 180),
    Color.fromARGB(255, 255, 105, 180),
  ];

  static List<Color> facebookGradient = const [
    Color.fromARGB(255, 66, 103, 178),
    Color.fromARGB(255, 58, 89, 152),
    Color.fromARGB(255, 44, 62, 103),
  ];

  static List<Color> linkedInGradient = const [
    Color.fromARGB(255, 0, 119, 181),
    Color.fromARGB(255, 26, 145, 218),
    Color.fromARGB(255, 21, 114, 171),
  ];

  static LinearGradient darkGreenLinear2() => const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF021B16), // dark
      Color(0xFF0D4436), // primary
      Color(0xFF0D4436), // primary
      Color(0xFF021B16), //
    ],
  );

  static LinearGradient greyLinear2() => const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF3F4F6), Color(0xFFE5E7EB)],
  );

  static LinearGradient verticalLinear() => const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF017865), Color(0xFF0D4436), Color(0xFF017865)],
  );

  static RadialGradient darkGreenRadial2() => const RadialGradient(
    center: Alignment.center,
    // Moved to the exact middle
    radius: 1.0,
    // Adjust this between 0.8 and 1.5 depending on your container size
    colors: [
      Color(0xFF0D5D4F), // Lighter teal/green (center glow)
      Color(0xFF032823), // Dark teal/green (outer edges)
    ],
    stops: [0.0, 1.0], // Smooth, continuous fade
  );

  static LinearGradient greenOpacityLinear() => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomLeft,
    colors: [
      const Color(0xFF017865).withValues(alpha: 0.87),
      const Color(0xFF017865), // 100%
    ],
  );

  static LinearGradient totalLearningLinear() => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomLeft,
    colors: [
      Color(0xFF017865),
      Color(0xFF50B89F), // 100%#
    ],
  );

  static LinearGradient minimumLearningLinear() => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomLeft,
    colors: [
      const Color(0xFFFFFFFF),
      const Color(0xFF50B89F).withValues(alpha: 0.1),
      const Color(0xFFFFFFFF),
    ],
  );

  static LinearGradient minimumSalaryLinear() => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomLeft,
    colors: [
      const Color(0xFFFFFFFF),
      const Color(0xFF50B89F).withValues(alpha: 0.1), // 100%#
    ],
  );

  static RadialGradient greenBgRadial() => const RadialGradient(
    center: Alignment.center,
    radius: 1.0,
    colors: [
      Color(0xFF0D4436),
      Color(0xFF0D4436),
      Color(0xFF017865),
      Color(0xFF017865),
    ],
    stops: [0.0, 0.3, 0.8, 1.0],
  );

  static LinearGradient lightGreenButtonLinear() => const LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xFF50B89F),
      Color(0xFF339F82), // Lighter teal (Left)
      Color(0xFF227E66),
      Color(0xFF017865), // Darker teal (Right)
      // Color(0xFF227E66), // Darker teal (Right)
    ],
  );

  static LinearGradient lightGreenContainerLinear() => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.centerRight,
    colors: [Color(0xff017865), Color(0xff50B89F)],
  );
}

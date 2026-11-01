import 'package:flutter/material.dart';
import 'core/constants/app_constants.dart';
import 'features/alerts/presentation/widgets/alerts_listener.dart';
import 'features/product/presentation/screens/main_screen.dart';

class PreVencApp extends StatelessWidget {
  const PreVencApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertsListener(
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          useMaterial3: true,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: const MainScreen(),
      ),
    );
  }
}

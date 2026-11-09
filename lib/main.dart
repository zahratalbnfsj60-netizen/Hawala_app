import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/app_provider.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(MyApp(prefs: prefs));
}

class MyApp extends StatelessWidget {
  final SharedPreferences prefs;
  const MyApp({super.key, required this.prefs});
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider(prefs)..init(),
      child: Consumer<AppProvider>(
        builder: (context, p, _) {
          return MaterialApp(
            title: 'سجل الحوالات',
            debugShowCheckedModeBanner: false,
            themeMode: ThemeMode.dark,
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: Colors.black,
              colorScheme: ColorScheme.dark(primary: p.accentColor, secondary: p.accentColor, surface: const Color(0xFF161616), error: const Color(0xFFE53935)),
              textTheme: GoogleFonts.getTextTheme(p.fontFamily, ThemeData.dark().textTheme),
              pageTransitionsTheme: const PageTransitionsTheme(builders: {TargetPlatform.android: _NoTransitions()}),
              useMaterial3: true,
              cardTheme: const CardTheme(color: Color(0xFF161616), shape: RoundedRectangleBorder(side: BorderSide(color: Color(0xFF333333)), borderRadius: BorderRadius.all(Radius.circular(12)))),
            ),
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
            builder: (c, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
            home: const SplashScreen(),
          );
        }
      ),
    );
  }
}

class _NoTransitions extends PageTransitionsBuilder {
  const _NoTransitions();
  @override
  Widget buildTransitions<T>(PageRoute<T> r, BuildContext c, Animation<double> a, Animation<double> b, Widget child) => child;
}

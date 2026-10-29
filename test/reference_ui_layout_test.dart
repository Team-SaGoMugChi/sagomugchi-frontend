import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oddo/app/router/app_router.dart';
import 'package:oddo/app/router/app_routes.dart';
import 'package:oddo/core/config/app_config.dart';
import 'package:oddo/core/config/app_config_provider.dart';
import 'package:oddo/core/storage/local_store.dart';
import 'package:oddo/features/onboarding/application/onboarding_controller.dart';
import 'package:oddo/features/records/application/viewing_date_provider.dart';
import 'package:oddo/theme/app_theme.dart';
import 'package:oddo/theme/app_typography.dart';
import 'package:shared_preferences/shared_preferences.dart';

const screenshots = bool.fromEnvironment('UI_SCREENSHOTS');
void main() {
  setUpAll(() async {
    if (screenshots) {
      final font = File(r'C:\Windows\Fonts\malgun.ttf');
      final loader = FontLoader('ReferenceUI');
      loader.addFont(
        Future.value(ByteData.sublistView(font.readAsBytesSync())),
      );
      await loader.load();
      final icons = FontLoader('MaterialIcons');
      icons.addFont(
        Future.value(
          ByteData.sublistView(
            File(
              r'C:\src\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf',
            ).readAsBytesSync(),
          ),
        ),
      );
      await icons.load();
    }
  });
  for (final item in [
    ('login', AppPath.login),
    ('introduction', AppPath.appIntroduction),
    ('home', AppPath.home),
    ('calendar', AppPath.monthlyCalendar),
    ('my', AppPath.myPage),
    ('report', AppPath.recordsReport),
  ]) {
    testWidgets('reference UI fits a small phone: ${item.$1}', (tester) async {
      tester.view.physicalSize = screenshots
          ? const Size(390, 844)
          : const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              environment: AppEnvironment.dev,
              appName: 'UI test',
              apiBaseUrl: '',
              useDummyData: true,
            ),
          ),
          localStoreProvider.overrideWithValue(LocalStore(prefs)),
        ],
      );
      addTearDown(container.dispose);
      final router = container.read(goRouterProvider);
      router.go(item.$2);
      container.read(onboardingCompleteProvider.notifier).set(true);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: RepaintBoundary(
            key: boundary,
            child: MaterialApp.router(
              routerConfig: router,
              theme: AppTheme.light.copyWith(
                elevatedButtonTheme: screenshots
                    ? ElevatedButtonThemeData(
                        style: AppTheme.light.elevatedButtonTheme.style!
                            .copyWith(
                              textStyle: WidgetStatePropertyAll(
                                AppTypography.button.copyWith(
                                  fontFamily: 'ReferenceUI',
                                ),
                              ),
                            ),
                      )
                    : null,
                textButtonTheme: screenshots
                    ? TextButtonThemeData(
                        style: AppTheme.light.textButtonTheme.style!.copyWith(
                          textStyle: WidgetStatePropertyAll(
                            AppTypography.bodySecondary.copyWith(
                              fontFamily: 'ReferenceUI',
                            ),
                          ),
                        ),
                      )
                    : null,
                appBarTheme: screenshots
                    ? AppTheme.light.appBarTheme.copyWith(
                        titleTextStyle: AppTypography.subtitle.copyWith(
                          fontFamily: 'ReferenceUI',
                        ),
                      )
                    : null,
                textTheme: AppTheme.light.textTheme.apply(
                  fontFamily: screenshots ? 'ReferenceUI' : null,
                ),
              ),
              debugShowCheckedModeBanner: false,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(screenshots ? 1 : 1.25),
                ),
                child: child!,
              ),
            ),
          ),
        ),
      );
      if (screenshots) {
        await tester.runAsync(() async {
          for (final widget in tester.widgetList<Image>(find.byType(Image))) {
            await precacheImage(widget.image, boundary.currentContext!);
          }
        });
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (screenshots) {
        await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await render.toImage(pixelRatio: 2);
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          final directory = Directory('build/ui-review')
            ..createSync(recursive: true);
          File(
            '${directory.path}/${item.$1}.png',
          ).writeAsBytesSync(png!.buffer.asUint8List());
          image.dispose();
        });
      }
      if (item.$1 == 'home') {
        final tiles = find.byType(ListTile);
        if (tiles.evaluate().isNotEmpty) {
          final before = container.read(viewingDateProvider);
          await tester.ensureVisible(tiles.first);
          await tester.pumpAndSettle();
          await tester.tap(tiles.first);
          await tester.pumpAndSettle();
          expect(container.read(viewingDateProvider).isBefore(before), isTrue);
          expect(tester.takeException(), isNull);
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}

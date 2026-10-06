/// Tests for `UrlPolicy` (§5.3): same origin allowed, foreign origins external
/// at top level but allowed in frames, tel/mail/sms/maps/WhatsApp external,
/// in-page schemes allowed, unknown custom schemes cancelled.
///
/// Status: active — part of `flutter test`.
library;

import 'package:dynaopsapp/features/shell/cubit/url_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = UrlPolicy('https://app.dynaops.example');

  NavigationDecision decide(String url, {bool isMainFrame = true}) =>
      policy.decide(Uri.parse(url), isMainFrame: isMainFrame);

  test('same origin stays in the WebView', () {
    expect(decide('https://app.dynaops.example/field-sales/my-journey'), NavigationDecision.allow);
  });

  test('other origins open externally at top level but are allowed in frames', () {
    expect(decide('https://example.org/'), NavigationDecision.external);
    expect(decide('https://example.org/', isMainFrame: false), NavigationDecision.allow);
    expect(decide('http://app.dynaops.example/'), NavigationDecision.external, reason: 'scheme is part of the origin');
  });

  test('phone, mail, sms, maps and navigation links leave the app', () {
    for (final url in [
      'tel:+201000000000',
      'mailto:rep@example.com',
      'sms:+201000000000',
      'geo:30.0,31.2',
      'google.navigation:q=30.0,31.2',
      'whatsapp://send?phone=1',
      'https://www.google.com/maps/dir/?api=1&destination=30,31',
      'https://maps.app.goo.gl/abc',
    ]) {
      expect(decide(url), NavigationDecision.external, reason: url);
    }
  });

  test('in-page schemes are allowed', () {
    expect(decide('about:blank'), NavigationDecision.allow);
    expect(decide('blob:https://app.dynaops.example/123'), NavigationDecision.allow);
  });

  test('unknown custom schemes are cancelled, dyngis included', () {
    expect(decide('dyngis://signin?handoff=abc'), NavigationDecision.cancel);
    expect(decide('intent://scan/#Intent;end'), NavigationDecision.cancel);
    expect(decide('file:///sdcard/x.pdf'), NavigationDecision.cancel);
  });
}

// Complaints reach a person: the fallback email goes to the support inbox,
// readable in any mail app (2026-09-30).

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/support/data/support_tickets.dart';

void main() {
  test('the inbox is the support team', () {
    expect(SupportTickets.inbox, 'astralabs.supp@gmail.com');
  });

  test('the fallback email is addressed, titled and carries a short log', () {
    final uri = SupportTickets.mailto(
      subject: 'الصيدلية فاضية',
      message: 'مش بتعرض أي حاجة',
      crashLog: 'x' * 5000,
    );
    expect(uri.scheme, 'mailto');
    expect(uri.path, 'astralabs.supp@gmail.com');
    final query = Uri.decodeComponent(uri.query);
    expect(query, contains('subject=[زاد – دعم] الصيدلية فاضية'));
    expect(query, contains('مش بتعرض أي حاجة'));
    expect(query, contains('سجل الأعطال'));
    // Spaces as %20, not '+', which mail apps show literally.
    expect(uri.query, isNot(contains('+')));
    expect(query.length, lessThan(2000));
  });
}

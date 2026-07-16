import 'package:flutter_test/flutter_test.dart';
import 'package:mkg_tax_mobile/core/platform/platform_api.dart';
import 'package:mkg_tax_mobile/core/tax_year/tax_year_repository.dart';
import 'package:dio/dio.dart';

void main() {
  test('PlatformApi unwraps Laravel data envelope', () {
    final res = Response(
      requestOptions: RequestOptions(path: '/x'),
      data: {
        'data': {
          'years': [
            {'tax_year': 2025, 'label': '2025', 'is_current_filing_year': true},
          ],
          'meta': {'current_filing_tax_year': 2025},
        },
      },
      statusCode: 200,
    );
    final map = PlatformApi.unwrapMap(res);
    expect(map?['meta']?['current_filing_tax_year'], 2025);
    expect((map?['years'] as List).length, 1);
  });

  test('TaxYearWorkspace.fromJson maps Laravel workspace fields', () {
    final ws = TaxYearWorkspace.fromJson({
      'id': 'ws-1',
      'mobile_entity_id': 'ent-1',
      'tax_year': 2025,
      'federal_return_status': 'not_started',
      'organizer_status': 'in_progress',
      'organizer_completion_percentage': 40,
      'state_workspaces': [
        {'state_code': 'CA', 'residency_type': 'resident'},
      ],
      'documents': [
        {'id': 'd1'},
        {'id': 'd2'},
      ],
    });
    expect(ws.workspaceId, 'ws-1');
    expect(ws.entityId, 'ent-1');
    expect(ws.taxYear, 2025);
    expect(ws.federalReturnStatus, 'Not Started');
    expect(ws.organizerStatus, 'In Progress');
    expect(ws.organizerCompletionPercentage, 40);
    expect(ws.stateReturns.length, 1);
    expect(ws.documentsCount, 2);
  });
}

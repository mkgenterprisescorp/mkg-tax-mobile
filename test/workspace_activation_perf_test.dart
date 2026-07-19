import 'package:flutter_test/flutter_test.dart';
import 'package:mkg_tax_mobile/core/tax_year/tax_year_repository.dart';

void main() {
  group('WorkspaceActivation', () {
    test('fromJson workspace preserves ids used for snapshot matching', () {
      final workspace = TaxYearWorkspace.fromJson({
        'id': 'ws-1',
        'mobile_entity_id': 'ent-1',
        'tax_year': 2025,
        'federal_return_status': 'not_started',
        'organizer_status': 'in_progress',
        'organizer_completion_percentage': 40,
        'tasks': const [],
        'organizer': {
          'id': 'org-1',
          'tax_year_workspace_id': 'ws-1',
          'prep_type': 'personal',
          'sections': {
            'catalog': {},
            'answers': {
              'filing_info': {
                'answers': {'prepType': 'personal', 'filingStatus': 'single'},
              },
            },
          },
        },
      });

      expect(workspace.workspaceId, 'ws-1');
      expect(workspace.entityId, 'ent-1');
      expect(workspace.taxYear, 2025);
      expect(workspace.organizerCompletionPercentage, 40);
    });

    test('packed activate marks tasksEmbedded even when tasks empty', () {
      const packed = WorkspaceActivation(
        workspace: TaxYearWorkspace(
          taxYear: 2025,
          federalReturnStatus: 'Not Started',
          organizerStatus: 'In Progress',
          organizerCompletionPercentage: 0,
          workspaceId: 'ws-1',
        ),
        tasks: [],
        organizer: {
          'id': 'org-1',
          'tax_year_workspace_id': 'ws-1',
          'prep_type': 'personal',
        },
        tasksEmbedded: true,
      );

      // When tasksEmbedded is true, refreshWorkspace must not call listTasks.
      expect(packed.tasksEmbedded, isTrue);
      expect(packed.tasks, isEmpty);
      expect(packed.organizer?['tax_year_workspace_id'], 'ws-1');
    });
  });
}

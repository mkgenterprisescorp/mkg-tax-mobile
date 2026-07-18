/// Role model mirroring mkgtaxconsultants.com `use-nav-context.ts`.
///
/// The mobile product ships as **two experiences** from one Flutter binary:
/// - **Consumer** (`client`) — personal tax filing, documents, payments, Tessa AI
/// - **Professional** (preparer/admin/ERO staff) — client management, all returns, iERO, etc.
library;

const adminRoles = {
  'super_user',
  'admin',
  'manager',
  'regional_manager',
  'district_manager',
};

const professionalRoles = {
  'super_user',
  'admin',
  'manager',
  'regional_manager',
  'district_manager',
  'office_manager',
  'tax_preparer',
  'ea',
  'cpa',
  'loan_officer',
  'processor',
  'tax_attorney',
  'realtor',
  'insurance_agent',
  'bookkeeper',
  'ero',
};

enum AppEdition {
  consumer,
  professional,
}

extension AppEditionX on AppEdition {
  String get label => this == AppEdition.professional ? 'Professional' : 'Consumer';
}

AppEdition editionForRole(String? role) {
  final r = (role ?? 'client').toLowerCase();
  if (professionalRoles.contains(r)) return AppEdition.professional;
  return AppEdition.consumer;
}

bool isAdminRole(String? role) => adminRoles.contains((role ?? '').toLowerCase());

bool isProfessionalRole(String? role) => professionalRoles.contains((role ?? '').toLowerCase());

class RoleCapabilities {
  const RoleCapabilities(this.role);

  final String role;

  AppEdition get edition => editionForRole(role);
  bool get isConsumer => edition == AppEdition.consumer;
  bool get isProfessional => edition == AppEdition.professional;
  bool get isAdmin => isAdminRole(role);

  /// Staff queue of every return.
  bool get canManageAllReturns => isProfessional;

  /// Assigned / all clients list.
  bool get canManageClients => isProfessional;

  /// IRS iERO / bureau tools (admin-heavy on web; expose to pros with fallback).
  bool get canUseIeroTools => isProfessional;

  /// Consumer personal tax loop.
  bool get canFilePersonalReturn => true;
}

RoleCapabilities capabilitiesFor(String? role) => RoleCapabilities((role ?? 'client').toLowerCase());

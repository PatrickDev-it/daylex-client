/// The sites a new tab offers: where Italian lawyers read the law, the case law and the press, and the lawyer's own.
library;

enum PortalGroup {
  /// The State's own sources: free, official.
  official,

  /// Paid databases and the press, behind the lawyer's subscription.
  databases,

  /// Added by the lawyer.
  mine,
}

class Portal {
  const Portal({required this.id, required this.name, required this.url, this.group = PortalGroup.mine});

  final String id;
  final String name;
  final String url;
  final PortalGroup group;

  Portal named(String name) => Portal(id: id, name: name, url: url, group: group);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'url': url, 'group': group.name};

  /// Null for an entry this app cannot read: it is left out, never guessed.
  static Portal? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'], name = json['name'], url = json['url'];
    if (id is! String || name is! String || url is! String) return null;
    return Portal(
      id: id,
      name: name,
      url: url,
      group: PortalGroup.values.asNameMap()[json['group']] ?? PortalGroup.mine,
    );
  }
}

/// The ready list. An id is never reused: a lawyer who removed one does not get it back with the next version, a
/// new id does reach every lawyer once. Leggi d'Italia is not here: since 2026-11 its address leads to OneLegale.
const builtInPortals = [
  Portal(
    id: 'gazzetta-ufficiale',
    name: 'Gazzetta Ufficiale',
    url: 'https://www.gazzettaufficiale.it/',
    group: PortalGroup.official,
  ),
  Portal(id: 'normattiva', name: 'Normattiva', url: 'https://www.normattiva.it/', group: PortalGroup.official),
  Portal(
    id: 'italgiure',
    name: 'Cassazione — Italgiure',
    url: 'https://www.italgiure.giustizia.it/sncass/',
    group: PortalGroup.official,
  ),
  Portal(id: 'pst', name: 'PST Giustizia', url: 'https://pst.giustizia.it/PST/', group: PortalGroup.official),
  Portal(id: 'dejure', name: 'DeJure', url: 'https://dejure.lefebvregiuffre.it/', group: PortalGroup.databases),
  Portal(
    id: 'onelegale',
    name: 'OneLegale',
    url: 'https://onelegale.wolterskluwer.it/',
    group: PortalGroup.databases,
  ),
  Portal(id: 'sole24ore', name: 'Il Sole 24 Ore', url: 'https://www.ilsole24ore.com/', group: PortalGroup.databases),
];

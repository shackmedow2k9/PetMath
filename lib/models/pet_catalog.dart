import 'pet_model.dart';

/// Danh mục 10 mẫu thú cưng — mỗi mẫu tương ứng 1 loài trong [PetSpecies]
/// (cũng là 1 họ trong assets/pets_v2/). Khi học sinh bốc túi mù, hệ thống
/// random 1 mẫu trong danh sách này.
///
/// [PetTemplate.id] = thứ tự enum [PetSpecies] + 1. Không còn dùng ảnh trên
/// Firebase Hosting (/pets/N.png) nên `imageUrl` để rỗng — UI hiện emoji.
class PetCatalog {
  static const Map<PetSpecies, String> _emoji = {
    PetSpecies.bunny: '🐰',
    PetSpecies.cat: '🐱',
    PetSpecies.chicken: '🐤',
    PetSpecies.dog: '🐶',
    PetSpecies.dragon: '🐉',
    PetSpecies.kitsune: '🦊',
    PetSpecies.panda: '🐼',
    PetSpecies.robot: '🤖',
    PetSpecies.slime: '💧',
    PetSpecies.whale: '🐋',
  };

  /// Danh sách đầy đủ 10 mẫu, theo thứ tự enum [PetSpecies].
  static final List<PetTemplate> all = List<PetTemplate>.unmodifiable([
    for (final s in PetSpecies.values)
      PetTemplate(id: s.index + 1, name: s.displayName, emoji: _emoji[s]!),
  ]);

  static PetTemplate byId(int id) =>
      all.firstWhere((t) => t.id == id, orElse: () => all.first);

  /// Mẫu tương ứng với 1 loài.
  static PetTemplate forSpecies(PetSpecies species) => all[species.index];
}

class PetTemplate {
  final int id;
  final String name;
  final String emoji;
  final String imageUrl;

  const PetTemplate({
    required this.id,
    required this.name,
    required this.emoji,
    this.imageUrl = '',
  });
}

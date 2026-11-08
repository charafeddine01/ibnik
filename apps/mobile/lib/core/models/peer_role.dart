enum PeerRole {
  baby,
  parent,
}

extension PeerRoleExtension on PeerRole {
  String get value {
    switch (this) {
      case PeerRole.baby:
        return 'baby';
      case PeerRole.parent:
        return 'parent';
    }
  }

  static PeerRole fromString(String role) {
    if (role.toLowerCase() == 'baby') {
      return PeerRole.baby;
    }
    return PeerRole.parent;
  }
}

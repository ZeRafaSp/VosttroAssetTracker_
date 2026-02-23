    // Usaremos esta classe para representar um cliente no dropdown
    class ClientDropdownItem {
      final String id;
      final String name;

      ClientDropdownItem({required this.id, required this.name});

      @override
      bool operator ==(Object other) =>
          identical(this, other) ||
          other is ClientDropdownItem && runtimeType == other.runtimeType && id == other.id && name == other.name;

      @override
      int get hashCode => id.hashCode ^ name.hashCode;
    }


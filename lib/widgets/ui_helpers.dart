import 'package:flutter/material.dart';

BoxDecoration cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 8,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

Widget infoCard({required String title, required List<Widget> children}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  );
}

Widget readField(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14)),
      ],
    ),
  );
}

Widget statusChip(String status) {
  final color = status == "Ativo" ? Colors.green : Colors.orange;

  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(status, style: TextStyle(color: color)),
  );
}

Widget statusDot(String status) {
  return Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(
      color: getStatusColor(status),
      shape: BoxShape.circle,
    ),
  );
}

Color getStatusColor(String status) {
  switch (status) {
    case 'alugado':
      return Colors.orange;

    case 'estoque':
      return Colors.green;

    case 'alugado_em_manutencao':
      return Colors.purple;

    case 'manutencao':
      return Colors.red;

    case 'estoque_danificado':
      return const Color.fromARGB(255, 168, 75, 96);

    default:
      return Colors.grey;
  }
}
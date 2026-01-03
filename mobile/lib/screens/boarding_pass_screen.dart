// boarding_pass_screen.dart - Экран посадочного талона

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';

class BoardingPassScreen extends StatelessWidget {
  final BoardingPass pass;

  const BoardingPassScreen({super.key, required this.pass});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Посадочный талон'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pass.flightNumber.isNotEmpty ? 'Рейс ${pass.flightNumber}' : 'Посадочный талон',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _row('Passenger name', pass.passengerName),
                if (pass.passengerEmail != null && pass.passengerEmail!.isNotEmpty)
                  _row('Email', pass.passengerEmail!),
                if (pass.passengerPhone != null && pass.passengerPhone!.isNotEmpty)
                  _row('Phone', pass.passengerPhone!),
                if (pass.passengerNationality != null && pass.passengerNationality!.isNotEmpty)
                  _row('Nationality', pass.passengerNationality!),
                _row('Seat', pass.seat),
                _row('Gate', pass.gate.isEmpty ? '-' : pass.gate),
                _row('Boarding time', DateFormat('dd MMM yyyy, HH:mm').format(pass.boardingTime)),
                _row('Boarding pass #', pass.boardingPassNumber),
                const SizedBox(height: 16),
                const Text(
                  'QR payload',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SelectableText(
                    pass.qrPayload,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}



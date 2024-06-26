// model.dart

import 'package:flutter/material.dart';

class MenuItem {
  final String name;
  final IconData icon;

  MenuItem(this.name, this.icon);
}

class Order {
  final IconData icon;
  final String name;
  final int packs;
  final String status;
  final String date;
  Order(this.icon, this.name, this.packs, this.status, this.date);
}

class mBuildings {
  final String title;
  final String imgUrl;
  final String time;
  final String description;

  mBuildings(this.time, this.title, this.imgUrl, [this.description = '']);
}

// class BussinessStatus {
//   final String name;
//   final String value;
//   final String? iconPath;
//   final IconData? icon;

//   BussinessStatus(this.name, this.value, {this.icon, this.iconPath});
// }

class BussinessStatus {
  final String name;
  final String value;
  final IconData icon;

  BussinessStatus(this.name, this.value, this.icon);
}

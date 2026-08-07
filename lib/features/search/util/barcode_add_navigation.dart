import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';

void navigateHomeAfterBarcodeAdd(BuildContext context) {
  context.go(AppConstants.routeHome);
}

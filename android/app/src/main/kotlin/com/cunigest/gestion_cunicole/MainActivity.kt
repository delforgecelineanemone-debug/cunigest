package com.cunigest.gestion_cunicole

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (et non FlutterActivity) est requis par local_auth
// pour afficher le prompt biométrique natif Android.
class MainActivity : FlutterFragmentActivity()

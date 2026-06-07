package com.flutter.music

import android.app.Application
import com.ryanheise.audioservice.AudioServicePlugin

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        AudioServicePlugin.setFlutterEngineId("com.flutter.music.MainActivity")
    }
}

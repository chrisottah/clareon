# Android & iOS Permission Setup

After running `flutter create .`, you need to add these permissions manually.

## Android — android/app/src/main/AndroidManifest.xml

Add these lines BEFORE the `<application` tag:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

Inside the `<application` tag, add:
```xml
<service
    android:name="com.ryanheise.audioservice.AudioService"
    android:foregroundServiceType="microphone"
    android:exported="true">
    <intent-filter>
        <action android:name="android.media.browse.MediaBrowserService" />
    </intent-filter>
</service>
```

## iOS — ios/Runner/Info.plist

Add inside the `<dict>` tag:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Clareon needs microphone access to record your meetings.</string>
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

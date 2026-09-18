import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ponytail: 加载 android/key.properties(本机签名材料,git 忽略)。
//          没有 key.properties 时回落到空 Properties — release 构建会失败,
//          debug 构建不受影响(继续用 debug key)。
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) load(f.inputStream())
}

android {
    namespace = "app.qingzhang.qingzhang"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    signingConfigs {
        create("release") {
            // ponytail: 四个字段从 key.properties 读。文件不存在时全部 null,
            //          Gradle 会在 buildTypes.release 引用时报错 —— 这是好事,
            //          强制开发者配签名而不是默默签成 debug。
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "app.qingzhang.qingzhang"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // ponytail: 开关 = flutter build apk --debug / --release。
            //   --debug    → 默认 debug 签名,debuggable,无 R8 → 测试包
            //   --release → 走 release 签名(R8 压缩 + 资源瘦身)→ 线上包
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true       // ponytail: R8 开启,DEX 体积 -30%~-60%
            isShrinkResources = true     // ponytail: 配合 R8,无引用资源一起删
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
        debug {
            // ponytail: 显式声明用 debug key,而不是继承默认 — 调试包永远 debug 签,
            // 避免有人改了 release 默认值后把测试包也变成 release 签名。
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

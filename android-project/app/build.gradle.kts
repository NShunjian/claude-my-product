import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
}

// 加载 app/key.properties(本机签名材料,git 忽略)。
// 没有 key.properties 时回落到空 Properties — release 构建会失败,
// debug 构建不受影响(继续用 debug key)。
// 注意:用 file() 解析到当前 module(也就是 :app)的 projectDir,而不是项目根;
// rootProject 在这里是顶层 build.gradle,会导致路径错位。
val keystoreProperties = Properties().apply {
    val f = file("key.properties")
    if (f.exists()) load(f.inputStream())
}

android {
    namespace = "com.example.myapplication"
    compileSdk {
        version = release(37)
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    defaultConfig {
        applicationId = "com.example.myapplication"
        minSdk = 24
        targetSdk = 37
        versionCode = 1
        versionName = "1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            // 开关 = ./gradlew :app:assembleDebug / :app:assembleRelease / :app:bundleRelease
            //   assembleDebug   → 默认 debug 签名,debuggable,无 R8 → 测试包
            //   assembleRelease → 走 release 签名 + R8 + 资源瘦身 → 线上 APK
            //   bundleRelease   → 走 release 签名 + R8 + 资源瘦身 → 线上 AAB(Play 上架)
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true       // R8 开启,DEX 体积 -30% 到 -60%
            isShrinkResources = true     // 配合 R8,无引用资源一起删
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
        debug {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    buildFeatures {
        compose = true
    }
}

dependencies {
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.graphics)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    testImplementation(libs.junit)
    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.compose.ui.test.junit4)
    androidTestImplementation(libs.androidx.espresso.core)
    androidTestImplementation(libs.androidx.junit)
    debugImplementation(libs.androidx.compose.ui.test.manifest)
    debugImplementation(libs.androidx.compose.ui.tooling)
}
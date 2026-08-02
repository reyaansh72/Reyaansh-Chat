allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// Ensure all Android subprojects use a minimum compileSdk of 36 so
// plugins compiled with older compileSdk (e.g., android-34) won't
// fail AAR metadata checks when other plugins require 36+.
subprojects {
    // Configure Android projects when their plugin is applied. Using
    // `plugins.withId` avoids calling `afterEvaluate` on projects that
    // have already been evaluated and prevents the "already evaluated"
    // exception on CI.
    plugins.withId("com.android.application") {
        extensions.findByName("android")
            ?.let { it as? com.android.build.gradle.BaseExtension }
            ?.apply { compileSdkVersion(36) }
    }

    plugins.withId("com.android.library") {
        extensions.findByName("android")
            ?.let { it as? com.android.build.gradle.BaseExtension }
            ?.apply { compileSdkVersion(36) }
    }
}

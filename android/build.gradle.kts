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

// AGP 9 “built-in Kotlin” leaves some plugins (e.g. screen_protector) without a compiled
// ScreenProtectorPlugin class. Force Kotlin Android when kotlin sources exist.
subprojects {
    pluginManager.withPlugin("com.android.library") {
        val kotlinDir = file("${project.projectDir}/src/main/kotlin")
        val hasKotlinPlugin =
            pluginManager.hasPlugin("org.jetbrains.kotlin.android") ||
                pluginManager.hasPlugin("kotlin-android")
        if (kotlinDir.exists() && !hasKotlinPlugin) {
            pluginManager.apply("org.jetbrains.kotlin.android")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

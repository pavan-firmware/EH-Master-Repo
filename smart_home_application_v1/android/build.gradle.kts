import com.android.build.api.dsl.LibraryExtension

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

    // reactive_ble_mobile currently declares compileSdk 33, while its
    // AndroidX dependencies require API 34+. Keep the plugin aligned with
    // the application compile SDK without modifying generated plugin files.
    plugins.withId("com.android.library") {
        extensions.configure<LibraryExtension> {
            compileSdk = 35
        }
    }

    afterEvaluate {
        if (name == "reactive_ble_mobile") {
            extensions.configure<LibraryExtension> {
                compileSdk = 35
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

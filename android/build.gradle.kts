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
// geolocator_android and image_editor_common still compile as Java 8, so javac warns that 8 is obsolete. Our app is
// Java 17; this only hides that one warning. Remove it once those plugins move past Java 8.
subprojects {
    tasks.withType<JavaCompile>().configureEach { options.compilerArgs.add("-Xlint:-options") }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

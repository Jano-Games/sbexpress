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
fun Project.raiseCompileSdk() {
    // Some libraries still compile against API 34 or 35. Flutter's lifecycle
    // plugin requires API 36, so raise them once their Android extension exists.
    val androidExt = extensions.findByName("android") ?: return
    val getter = androidExt.javaClass.methods.firstOrNull { it.name == "getCompileSdk" && it.parameterCount == 0 }
        ?: androidExt.javaClass.methods.firstOrNull { it.name == "getCompileSdkVersion" && it.parameterCount == 0 }
    val setter = androidExt.javaClass.methods.firstOrNull { it.name == "setCompileSdk" && it.parameterCount == 1 }
        ?: androidExt.javaClass.methods.firstOrNull { it.name == "setCompileSdkVersion" && it.parameterCount == 1 }
    val current = when (val value = getter?.invoke(androidExt)) {
        is Int -> value
        is String -> value.removePrefix("android-").toIntOrNull()
        else -> null
    } ?: return
    if (current < 36 && setter != null) setter.invoke(androidExt, 36)
}

subprojects {
    // Register before any project is evaluated. evaluationDependsOn below
    // evaluates :app immediately, and afterEvaluate cannot be added after that.
    if (state.executed) raiseCompileSdk() else afterEvaluate { raiseCompileSdk() }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

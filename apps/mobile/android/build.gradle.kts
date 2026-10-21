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
    // file_picker 8 still compiles against API 34. Flutter's lifecycle plugin
    // requires API 36, so raise older libraries before evaluation finishes.
    afterEvaluate {
        val androidExt = extensions.findByName("android") ?: return@afterEvaluate
        val getter = androidExt.javaClass.methods.firstOrNull { it.name == "getCompileSdk" && it.parameterCount == 0 }
        val setter = androidExt.javaClass.methods.firstOrNull { it.name == "setCompileSdk" && it.parameterCount == 1 }
        val current = getter?.invoke(androidExt) as? Int ?: return@afterEvaluate
        if (current < 36 && setter != null) setter.invoke(androidExt, 36)
    }
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

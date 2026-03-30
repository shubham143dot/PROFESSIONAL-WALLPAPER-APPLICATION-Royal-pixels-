buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.1")
    }
}

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
    afterEvaluate {
        if (project.hasProperty("android")) {
            val android = project.extensions.getByName("android")
            try {
                val getNamespace = android.javaClass.getMethod("getNamespace")
                val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                if (getNamespace.invoke(android) == null) {
                    if (project.name == "image_gallery_saver") {
                        setNamespace.invoke(android, "com.example.imagegallerysaver")
                    }
                }
            } catch (e: Exception) {
                // Method might not exist on older AGP versions
            }

            try {
                val compileOptions = android.javaClass.getMethod("getCompileOptions").invoke(android)
                compileOptions.javaClass.getMethod("setSourceCompatibility", org.gradle.api.JavaVersion::class.java)
                    .invoke(compileOptions, org.gradle.api.JavaVersion.VERSION_17)
                compileOptions.javaClass.getMethod("setTargetCompatibility", org.gradle.api.JavaVersion::class.java)
                    .invoke(compileOptions, org.gradle.api.JavaVersion.VERSION_17)
            } catch (e: Exception) {}
        }
    }

    project.tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = "17"
        targetCompatibility = "17"
    }

    // Force Kotlin jvmTarget to 17 for all subprojects that use kotlin-android
    plugins.withId("kotlin-android") {
        (project.extensions.findByName("kotlin")
            ?.let { ext ->
                try {
                    ext.javaClass.getMethod("getJvmOptions").invoke(ext)
                        .let { jvmOpts ->
                            jvmOpts.javaClass.getMethod("setJvmTarget", String::class.java)
                                .invoke(jvmOpts, "17")
                        }
                } catch (_: Exception) {}
                try {
                    // KotlinAndroidExtension path
                    ext.javaClass.getMethod("getTarget").invoke(ext).let { target ->
                        target.javaClass.getMethod("getCompilations").invoke(target).let { comps ->
                            @Suppress("UNCHECKED_CAST")
                            (comps as? Iterable<*>)?.forEach { comp ->
                                try {
                                    comp?.javaClass?.getMethod("getKotlinOptions")?.invoke(comp)?.let { opts ->
                                        opts.javaClass.getMethod("setJvmTarget", String::class.java).invoke(opts, "17")
                                    }
                                } catch (_: Exception) {}
                            }
                        }
                    }
                } catch (_: Exception) {}
            })
        // Fallback: set via task-level options
        project.tasks.configureEach {
            if (this.javaClass.name.contains("KotlinCompile")) {
                try {
                    val opts = this.javaClass.getMethod("getKotlinOptions").invoke(this)
                    opts.javaClass.getMethod("setJvmTarget", String::class.java).invoke(opts, "17")
                } catch (_: Exception) {}
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

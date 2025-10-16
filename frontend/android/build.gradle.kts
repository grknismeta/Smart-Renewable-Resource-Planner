allprojects {
    repositories {
        google()
        mavenCentral()
        // MAPBOX İÇİN SADECE BU BLOK GEREKLİ
        maven {
            url = uri("https://api.mapbox.com/downloads/v2/releases/maven")
            // HATA VEREN 'authentication' BLOĞU BU VERSİYONDA YOK
            credentials {
                username = "mapbox"
                password = project.properties["MAPBOX_DOWNLOADS_TOKEN"] as String? ?: ""
            }
        }
    }
}
    


val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
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

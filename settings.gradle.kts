val mirror = providers.gradleProperty("localMirror").orNull
pluginManagement {
    repositories {
        providers.gradleProperty("localMirror").orNull?.let { m ->
            listOf("google", "central", "plugins").forEach { r -> maven("$m/$r") { isAllowInsecureProtocol = true } }
        }
        google(); mavenCentral(); gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        mirror?.let { m -> listOf("google", "central").forEach { r -> maven("$m/$r") { isAllowInsecureProtocol = true } } }
        google(); mavenCentral()
    }
}
rootProject.name = "FuelPrices"
include(":app")

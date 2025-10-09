#[[====================================================================================================================

    Microsoft.WindowsAppSDK.Foundation

    CMake configuration file for Microsoft.WindowsAppSDK.Foundation package.

    This package provides CMake targets:

        find_package(Microsoft.WindowsAppSDK.Foundation CONFIG REQUIRED)

        target_link_libraries(<your-target>
            PRIVATE
                Microsoft.WindowsAppSDK.Foundation
        )

    License:
        See the LICENSE file in the package root for more information.
====================================================================================================================]]#
include_guard()

find_package(Microsoft.Windows.CppWinRT CONFIG REQUIRED)
find_package(Microsoft.WindowsAppSDK.InteractiveExperiences CONFIG REQUIRED)

if(NOT (TARGET Microsoft.Windows.CppWinRT))
    message(FATAL_ERROR "Microsoft.Windows.CppWinRT not found. Ensure that the Microsoft.Windows.CppWinRT dependency is correctly specified.")
endif()

block(SCOPE_FOR VARIABLES)
    # Set the 'PLATFORM_IDENTIFIER' - mapping CMake constructs to the identifiers that the NuGet package layout uses.
    if(CMAKE_GENERATOR MATCHES "^Visual Studio")
        set(PLATFORM_IDENTIFIER ${CMAKE_GENERATOR_PLATFORM})
    else()
        set(PLATFORM_PROCESSOR ${CMAKE_SYSTEM_PROCESSOR})
        if(PLATFORM_PROCESSOR STREQUAL "")
            set(PLATFORM_PROCESSOR ${CMAKE_HOST_PROCESSOR})
        endif()
        if(PLATFORM_PROCESSOR STREQUAL "AMD64")
            set(PLATFORM_IDENTIFIER "x64")
        elseif(PLATFORM_PROCESSOR STREQUAL "ARM64")
            set(PLATFORM_IDENTIFIER "arm64")
        endif()
    endif()

    if(PLATFORM_IDENTIFIER STREQUAL "")
        message(FATAL_ERROR "Unable to determine the platform identifier.")
    endif()

    # For 'overlay' configuration, rely on the 'NUGET_LOCATION-<package name>' global property set by the NuGetCMakePackage.
    # For 'laid out' configuration, this should rely on the location of the current file.
    get_property(PACKAGE_LOCATION GLOBAL PROPERTY NUGET_LOCATION-MICROSOFT_WINDOWSAPPSDK_FOUNDATION)
    get_property(PACKAGE_VERSION  GLOBAL PROPERTY NUGET_VERSION-MICROSOFT_WINDOWSAPPSDK_FOUNDATION)

    #[[====================================================================================================================
        Target: Microsoft.WindowsAppSDK.Foundation
    ====================================================================================================================]]#
    add_cppwinrt_projection(Microsoft.WindowsAppSDK.Foundation
        INPUTS
            ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.ApplicationModel.Background.UniversalBGTask.winmd
            ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.ApplicationModel.Background.winmd
            ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.ApplicationModel.DynamicDependency.winmd
            ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.ApplicationModel.Resources.winmd
            ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.ApplicationModel.WindowsAppRuntime.winmd
            ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.AppLifecycle.winmd
            ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.AppNotifications.Builder.winmd
            ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.AppNotifications.winmd
            ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.BadgeNotifications.winmd
            ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.Foundation.winmd
            ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.Globalization.winmd
            ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.Management.Deployment.winmd
            ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.Media.Capture.winmd
            ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.PushNotifications.winmd
            ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.Security.AccessControl.winmd
            ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.Storage.Pickers.winmd
            ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.Storage.winmd
            ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.System.Power.winmd
            ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.System.winmd
        OPTIMIZE
        DEPS
            Microsoft.WindowsAppSDK.InteractiveExperiences
    )

    target_include_directories(Microsoft.WindowsAppSDK.Foundation
        INTERFACE
            ${PACKAGE_LOCATION}/include
    )

    #[[====================================================================================================================
        Target: Microsoft.WindowsAppSDK.Foundation_SelfContained
    ====================================================================================================================]]#
    add_library(Microsoft.WindowsAppSDK.Foundation_SelfContainedRuntime SHARED IMPORTED GLOBAL)

    set(FRAMEWORK_PATH "${PACKAGE_LOCATION}/runtimes-framework/win-${PLATFORM_IDENTIFIER}/native")
    set(FRAMEWORK_DLLS
        "${FRAMEWORK_PATH}/Microsoft.Windows.ApplicationModel.Resources.dll"
        "${FRAMEWORK_PATH}/Microsoft.WindowsAppRuntime.dll"
    )

    set_target_properties(Microsoft.WindowsAppSDK.Foundation_SelfContainedRuntime
        PROPERTIES
            IMPORTED_IMPLIB "${PACKAGE_LOCATION}/lib/native/${PLATFORM_IDENTIFIER}/Microsoft.WindowsAppRuntime.lib"
            IMPORTED_LOCATION "${FRAMEWORK_DLLS}"
    )

    add_library(Microsoft.WindowsAppSDK.Foundation_SelfContained INTERFACE)

    target_sources(Microsoft.WindowsAppSDK.Foundation_SelfContained
        INTERFACE
            ${CMAKE_CURRENT_LIST_DIR}/Microsoft.WindowsAppSDK.Foundation.manifest
    )

    target_link_libraries(Microsoft.WindowsAppSDK.Foundation_SelfContained
        INTERFACE
            Microsoft.WindowsAppSDK.Foundation
            Microsoft.WindowsAppSDK.Foundation_SelfContainedRuntime
    )

endblock()

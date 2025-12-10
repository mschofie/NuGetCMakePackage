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

# Check for minimum CMake version. Avoid using `cmake_minimum_required`, which will reset policies if this file is
# included by a project that has already specified a minimum CMake version.
if(CMAKE_VERSION VERSION_LESS 3.31)
    message(FATAL_ERROR "Microsoft.WindowsAppSDK.Foundation requires at least CMake 3.31, but CMake ${CMAKE_VERSION} is in use.")
endif()

find_package(Microsoft.WindowsAppSDK.InteractiveExperiences CONFIG REQUIRED)

block(SCOPE_FOR VARIABLES)
    # For 'overlay' configuration, rely on the 'NUGET_LOCATION-<package name>' global property set by the NuGetCMakePackage.
    # For 'laid out' configuration, this should rely on the location of the current file.
    get_property(PACKAGE_LOCATION GLOBAL PROPERTY NUGET_LOCATION-MICROSOFT_WINDOWSAPPSDK_FOUNDATION)
    get_property(PACKAGE_VERSION  GLOBAL PROPERTY NUGET_VERSION-MICROSOFT_WINDOWSAPPSDK_FOUNDATION)

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

    set(RUNTIME_PATH "${PACKAGE_LOCATION}/runtimes/win-${PLATFORM_IDENTIFIER}/native")
    set(RUNTIME_DLLS
        "${RUNTIME_PATH}/Microsoft.Windows.ApplicationModel.Background.UniversalBGTask.dll"
        "${RUNTIME_PATH}/Microsoft.WindowsAppRuntime.Bootstrap.dll"
    )

    set(FRAMEWORK_PATH "${PACKAGE_LOCATION}/runtimes-framework/win-${PLATFORM_IDENTIFIER}/native")
    set(FRAMEWORK_DLLS
        "${FRAMEWORK_PATH}/Microsoft.Windows.ApplicationModel.Resources.dll"
        "${FRAMEWORK_PATH}/Microsoft.WindowsAppRuntime.dll"
        "${FRAMEWORK_PATH}/MRM.dll"
        "${FRAMEWORK_PATH}/PushNotificationsLongRunningTask.ProxyStub.dll"
    )

    #[[====================================================================================================================
        Target: Microsoft.WindowsAppSDK.Foundation
    ====================================================================================================================]]#
    add_library(Microsoft.WindowsAppSDK.Foundation INTERFACE)

    target_include_directories(Microsoft.WindowsAppSDK.Foundation
        INTERFACE
            ${PACKAGE_LOCATION}/include
    )

    set_property(TARGET Microsoft.WindowsAppSDK.Foundation
        APPEND PROPERTY
            INTERFACE_WINMD_INPUTS
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
    )

    set_property(TARGET Microsoft.WindowsAppSDK.Foundation APPEND PROPERTY INTERFACE_WINMD_DEPS Microsoft.WindowsAppSDK.InteractiveExperiences)
    set_property(TARGET Microsoft.WindowsAppSDK.Foundation APPEND PROPERTY INTERFACE_FRAMEWORK_DLL ${FRAMEWORK_DLLS})
    set_property(TARGET Microsoft.WindowsAppSDK.Foundation APPEND PROPERTY INTERFACE_FRAMEWORK_LIB ${PACKAGE_LOCATION}/lib/native/${PLATFORM_IDENTIFIER}/Microsoft.WindowsAppRuntime.lib)

    set_property(SOURCE ${PACKAGE_LOCATION}/metadata/Microsoft.Security.Authentication.OAuth.winmd                          PROPERTY WINMD_IMPLEMENTATION ${FRAMEWORK_PATH}/Microsoft.WindowsAppRuntime.dll)
    set_property(SOURCE ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.ApplicationModel.Background.UniversalBGTask.winmd    PROPERTY WINMD_IMPLEMENTATION ${FRAMEWORK_PATH}/Microsoft.Windows.ApplicationModel.UniversalBGTask.dll)
    set_property(SOURCE ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.ApplicationModel.Background.winmd                    PROPERTY WINMD_IMPLEMENTATION ${FRAMEWORK_PATH}/Microsoft.WindowsAppRuntime.dll)
    set_property(SOURCE ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.ApplicationModel.DynamicDependency.winmd             PROPERTY WINMD_IMPLEMENTATION ${FRAMEWORK_PATH}/Microsoft.WindowsAppRuntime.dll)
    set_property(SOURCE ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.ApplicationModel.WindowsAppRuntime.winmd             PROPERTY WINMD_IMPLEMENTATION ${FRAMEWORK_PATH}/Microsoft.WindowsAppRuntime.dll)
    set_property(SOURCE ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.AppLifecycle.winmd                                   PROPERTY WINMD_IMPLEMENTATION ${FRAMEWORK_PATH}/Microsoft.WindowsAppRuntime.dll)
    set_property(SOURCE ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.BadgeNotifications.winmd                             PROPERTY WINMD_IMPLEMENTATION ${FRAMEWORK_PATH}/Microsoft.WindowsAppRuntime.dll)
    set_property(SOURCE ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.Foundation.winmd                                     PROPERTY WINMD_IMPLEMENTATION ${FRAMEWORK_PATH}/Microsoft.WindowsAppRuntime.dll)
    set_property(SOURCE ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.Media.Capture.winmd                                  PROPERTY WINMD_IMPLEMENTATION ${FRAMEWORK_PATH}/Microsoft.WindowsAppRuntime.dll)
    set_property(SOURCE ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.PushNotifications.winmd                              PROPERTY WINMD_IMPLEMENTATION ${FRAMEWORK_PATH}/Microsoft.WindowsAppRuntime.dll)
    set_property(SOURCE ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.Security.AccessControl.winmd                         PROPERTY WINMD_IMPLEMENTATION ${FRAMEWORK_PATH}/Microsoft.WindowsAppRuntime.dll)
    set_property(SOURCE ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.Storage.Pickers.winmd                                PROPERTY WINMD_IMPLEMENTATION ${FRAMEWORK_PATH}/Microsoft.WindowsAppRuntime.dll)
    set_property(SOURCE ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.Storage.winmd                                        PROPERTY WINMD_IMPLEMENTATION ${FRAMEWORK_PATH}/Microsoft.WindowsAppRuntime.dll)
    set_property(SOURCE ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.System.Power.winmd                                   PROPERTY WINMD_IMPLEMENTATION ${FRAMEWORK_PATH}/Microsoft.WindowsAppRuntime.dll)
    set_property(SOURCE ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.System.winmd                                         PROPERTY WINMD_IMPLEMENTATION ${FRAMEWORK_PATH}/Microsoft.WindowsAppRuntime.dll)
endblock()

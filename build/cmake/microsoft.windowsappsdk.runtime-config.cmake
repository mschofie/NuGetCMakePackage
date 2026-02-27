#[[====================================================================================================================

    Microsoft.WindowsAppSDK.Runtime

    CMake configuration file for Microsoft.WindowsAppSDK.Runtime package.

    This package provides CMake targets:

        find_package(Microsoft.WindowsAppSDK.Runtime CONFIG REQUIRED)

        target_link_libraries(<your-target>
            PRIVATE
                Microsoft.WindowsAppSDK.Runtime
        )

    License:
        See the LICENSE file in the package root for more information.
====================================================================================================================]]#
include_guard()

cmake_minimum_required(VERSION 3.31)

block(SCOPE_FOR VARIABLES)
    # For 'overlay' configuration, rely on the 'NUGET_LOCATION-<package name>' global property set by the NuGetCMakePackage.
    # For 'laid out' configuration, this should rely on the location of the current file.
    get_property(PACKAGE_LOCATION GLOBAL PROPERTY NUGET_LOCATION-MICROSOFT_WINDOWSAPPSDK_RUNTIME)
    get_property(PACKAGE_VERSION  GLOBAL PROPERTY NUGET_VERSION-MICROSOFT_WINDOWSAPPSDK_RUNTIME)

    add_library(Microsoft.WindowsAppSDK.Runtime INTERFACE)

    target_include_directories(Microsoft.WindowsAppSDK.Runtime
        INTERFACE
            ${PACKAGE_LOCATION}/include
    )
endblock()

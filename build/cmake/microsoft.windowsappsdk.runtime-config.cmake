#[[====================================================================================================================

    Microsoft.WindowsAppSDK.Runtime

    CMake configuration file for Microsoft.WindowsAppSDK.Runtime package. Usage:

        add_nuget_library(Microsoft.WindowsAppSDK.Runtime <version>)

        target_link_libraries(<your-target>
            PRIVATE
                Microsoft.WindowsAppSDK.Runtime
        )

    License:
        See the LICENSE file in the package root for more information.
====================================================================================================================]]#
add_library(Microsoft.WindowsAppSDK.Runtime INTERFACE)

target_include_directories(Microsoft.WindowsAppSDK.Runtime
    INTERFACE
        ${NUGET_MICROSOFT_WINDOWSAPPSDK_RUNTIME}/include
)

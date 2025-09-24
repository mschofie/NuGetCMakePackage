#[[====================================================================================================================

    Microsoft.Windows.ImplementationLibrary
    ---------------------------------------

    CMake configuration file for the 'Microsoft.Windows.ImplementationLibrary' package.

    This package provides CMake targets:

        find_package(Microsoft.Windows.ImplementationLibrary CONFIG REQUIRED)

        target_link_libraries(<your-target>
            PRIVATE
                Microsoft.Windows.ImplementationLibrary
        )

    License:
        See the LICENSE file in the package root for more information.
====================================================================================================================]]#

# For 'overlay' configuration, rely on the 'NUGET_LOCATION-<package name>' global property set by the NuGetCMakePackage.
# For 'laid out' configuration, this should rely on the location of the current file.
get_property(PACKAGE_LOCATION GLOBAL PROPERTY NUGET_LOCATION-MICROSOFT_WINDOWS_IMPLEMENTATIONLIBRARY)
get_property(PACKAGE_VERSION  GLOBAL PROPERTY NUGET_VERSION-MICROSOFT_WINDOWS_IMPLEMENTATIONLIBRARY)

add_library(Microsoft.Windows.ImplementationLibrary INTERFACE)

target_include_directories(Microsoft.Windows.ImplementationLibrary
    INTERFACE
        ${PACKAGE_LOCATION}/include
)

unset(PACKAGE_LOCATION)
unset(PACKAGE_VERSION)

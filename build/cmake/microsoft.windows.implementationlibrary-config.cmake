#[[====================================================================================================================

====================================================================================================================]]#

add_library(Microsoft.Windows.ImplementationLibrary INTERFACE)

target_include_directories(Microsoft.Windows.ImplementationLibrary
    INTERFACE
        ${NUGET_MICROSOFT_WINDOWS_IMPLEMENTATIONLIBRARY}/include
)

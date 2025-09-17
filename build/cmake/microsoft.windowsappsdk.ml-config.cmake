#[[====================================================================================================================

    Microsoft.WindowsAppSDK.ML

    CMake configuration file for Microsoft.WindowsAppSDK.ML package. For consumption from a library, reference the
    'Microsoft.WindowsAppSDK.ML' library to get the Cpp/WinRT projection of the Windows ML API:

        add_nuget_library(Microsoft.WindowsAppSDK.ML <version>)

        target_link_libraries(<your-target>
            PRIVATE
                Microsoft.WindowsAppSDK.ML
        )

    Executable projects that want to use Windows ML should reference either the 'Microsoft.WindowsAppSDK.ML_Framework'
    or 'Microsoft.WindowsAppSDK.ML_SelfContained' targets which include the necessary infrastructure to find and load
    the Windows ML runtime.

    Note: This package has a dependency on the 'Microsoft.Windows.CppWinRT' package which must also be specified in
    the consuming project.

====================================================================================================================]]#
if(NOT (TARGET Microsoft.Windows.CppWinRT))
    message(FATAL_ERROR "Microsoft.Windows.CppWinRT not found. Ensure that the Microsoft.Windows.CppWinRT dependency is correctly specified.")
endif()



# TODO Figure out PLATFORM_IDENTIFIER
set(PLATFORM_IDENTIFIER win-x64)

#[[====================================================================================================================
    Target: Microsoft.WindowsAppSDK.ML

    The Cpp/WinRT projection for the Windows AI Machine Learning WinMD.
====================================================================================================================]]#
add_cppwinrt_projection(Microsoft.WindowsAppSDK.ML
    INPUTS
        ${NUGET_MICROSOFT_WINDOWSAPPSDK_ML}/metadata/Microsoft.Windows.AI.MachineLearning.winmd
    OPTIMIZE
    DEPS
        Microsoft.Windows.CppWinRT
)

target_include_directories(Microsoft.WindowsAppSDK.ML
    INTERFACE
        ${NUGET_MICROSOFT_WINDOWSAPPSDK_ML}/include
)

target_link_libraries(Microsoft.WindowsAppSDK.ML
    INTERFACE
        ole32.lib
        oleaut32.lib
)

#[[====================================================================================================================
    Target: Microsoft.WindowsAppSDK.ML_Framework
    The target for the framework dependencies of the Windows AI Machine Learning library.
====================================================================================================================]]#
add_library(Microsoft.WindowsAppSDK.ML_Framework INTERFACE)

target_compile_definitions(Microsoft.WindowsAppSDK.ML_Framework
    INTERFACE
        ORT_API_MANUAL_INIT
)

target_include_directories(Microsoft.WindowsAppSDK.ML_Framework
    INTERFACE
        ${CMAKE_CURRENT_LIST_DIR}/Stub
)

target_sources(Microsoft.WindowsAppSDK.ML_Framework
    INTERFACE
        ${NUGET_MICROSOFT_WINDOWSAPPSDK_ML}/include/WindowsMLAutoInitializer.cpp
        ${CMAKE_CURRENT_LIST_DIR}/Stub/winml/Runtime.cpp
)

target_link_libraries(Microsoft.WindowsAppSDK.ML_Framework
    INTERFACE
        Microsoft.WindowsAppSDK.ML
        Microsoft.WindowsAppSDK.Runtime
        onecoreuap.lib
)

#[[====================================================================================================================
====================================================================================================================]]#
add_library(Microsoft.WindowsAppSDK.ML_SelfContainedRuntime SHARED IMPORTED GLOBAL)

set_target_properties(Microsoft.WindowsAppSDK.ML_SelfContainedRuntime
    PROPERTIES
        IMPORTED_IMPLIB     "${NUGET_MICROSOFT_WINDOWSAPPSDK_ML}/runtimes/${PLATFORM_IDENTIFIER}/native/onnxruntime.lib"
        IMPORTED_LOCATION   "${NUGET_MICROSOFT_WINDOWSAPPSDK_ML}/runtimes-framework/${PLATFORM_IDENTIFIER}/native/onnxruntime.dll;${NUGET_MICROSOFT_WINDOWSAPPSDK_ML}/runtimes-framework/${PLATFORM_IDENTIFIER}/native/onnxruntime_providers_shared.dll;${NUGET_MICROSOFT_WINDOWSAPPSDK_ML}/runtimes-framework/${PLATFORM_IDENTIFIER}/native/DirectML.dll;${NUGET_MICROSOFT_WINDOWSAPPSDK_ML}/runtimes-framework/${PLATFORM_IDENTIFIER}/native/Microsoft.Windows.AI.MachineLearning.dll"
)

#[[====================================================================================================================
    Target: Microsoft.WindowsAppSDK.ML_SelfContained

    The target for the 'self-contained' dependencies of the Windows AI Machine Learning library.
====================================================================================================================]]#
add_library(Microsoft.WindowsAppSDK.ML_SelfContained INTERFACE)

target_sources(Microsoft.WindowsAppSDK.ML_SelfContained
    INTERFACE
        ${CMAKE_CURRENT_LIST_DIR}/microsoft.windowsappsdk.ml.manifest
        ${NUGET_MICROSOFT_WINDOWSAPPSDK_ML}/include/WindowsMLAutoInitializer.SelfContained.cpp
)

target_link_libraries(Microsoft.WindowsAppSDK.ML_SelfContained
    INTERFACE
        Microsoft.WindowsAppSDK.ML
        Microsoft.WindowsAppSDK.ML_SelfContainedRuntime
)

unset(PLATFORM_IDENTIFIER)

#include "Runtime.h"

#include <appmodel.h>
#include <winml/onnxruntime_cxx_api.h>
#include <WindowsAppSDK-VersionInfo.h> // Should be a WinML-scoped package...?

#define MICROSOFT_WINDOWSAPPSDK_ML_PACKAGE_FAMILY_NAME_W WINDOWSAPPSDK_RUNTIME_PACKAGE_FRAMEWORK_PACKAGEFAMILYNAME_W

static wchar_t* g_packageFullName = nullptr;
static wchar_t* g_packageDependencyId = nullptr;
static HRESULT g_initializationResult = E_NOT_VALID_STATE;
static PACKAGEDEPENDENCY_CONTEXT g_packageContext = nullptr;

///
///
///
static inline bool IsRunningOnArm64()
{
#if defined(_M_ARM64EC) || defined(_M_ARM64)
    return true;
#else
    static const bool isArm64Native = [] {
        USHORT processMachine{};
        USHORT nativeMachine{};
        const auto result{::IsWow64Process2(GetCurrentProcess(), &processMachine, &nativeMachine)};
        THROW_IF_WIN32_BOOL_FALSE_MSG(result, "Failed to retrieve native machine information");
        return nativeMachine == IMAGE_FILE_MACHINE_ARM64;
    }();
    return isArm64Native;
#endif
}

///
///
///
static inline PackageDependencyProcessorArchitectures GetPackageDependencyProcessorArchitectures()
{
#if defined(_M_ARM64)
    const PackageDependencyProcessorArchitectures architectures = PackageDependencyProcessorArchitectures_Arm64;
#elif defined(_M_X64)
    const PackageDependencyProcessorArchitectures architectures = PackageDependencyProcessorArchitectures_X64;
#elif defined(_M_ARM64EC)
    const PackageDependencyProcessorArchitectures architectures = IsRunningOnArm64() ? PackageDependencyProcessorArchitectures_Arm64 : PackageDependencyProcessorArchitectures_X64;
#endif
    return architectures;
}

///
///
///
WINMLBOOTSTRAP_API HRESULT WinMLInitialize()
{
    if (g_packageDependencyId != nullptr)
    {
        return g_initializationResult;
    }

    HRESULT result = S_OK;

    // Create the package dependency
    {
        PSID userContext = nullptr;
        const PackageDependencyProcessorArchitectures architectures = GetPackageDependencyProcessorArchitectures();
        const wchar_t* const packageFamilyName = MICROSOFT_WINDOWSAPPSDK_ML_PACKAGE_FAMILY_NAME_W;
        const PackageDependencyLifetimeKind lifetimeKind = PackageDependencyLifetimeKind_Process;
        const wchar_t* lifetimeArtifact = nullptr;
        CreatePackageDependencyOptions options = CreatePackageDependencyOptions_None;
        PACKAGE_VERSION minVersion;
        minVersion.Revision = 0;
        minVersion.Build = 0;
        minVersion.Minor = 0;
        minVersion.Major = 0;

        result = TryCreatePackageDependency(userContext, packageFamilyName, minVersion, architectures, lifetimeKind, lifetimeArtifact, options, &g_packageDependencyId);
        if (FAILED(result))
        {
            return result;
        }

        if (!g_packageDependencyId)
        {
            return E_UNEXPECTED;
        }
    }

    // Add the package dependency
    {
        int rank = 0;
        AddPackageDependencyOptions options = AddPackageDependencyOptions_PrependIfRankCollision;

        result = AddPackageDependency(g_packageDependencyId, rank, options, &g_packageContext, &g_packageFullName);
    }

    g_initializationResult = result;
    return result;
}

WINMLBOOTSTRAP_API void WinMLUninitialize()
{
    if (g_packageDependencyId)
    {
        ::HeapFree(::GetProcessHeap(), 0, g_packageDependencyId);
        g_packageDependencyId = nullptr;
    }

    if (g_packageFullName)
    {
        ::HeapFree(::GetProcessHeap(), 0, g_packageFullName);
        g_packageFullName = nullptr;
    }

    if (g_packageContext)
    {
        ::RemovePackageDependency(g_packageContext);
        g_packageContext = nullptr;
    }

    g_initializationResult = E_NOT_VALID_STATE;
}

namespace Microsoft::Windows::AI::MachineLearning
{
    WinMLRuntime::WinMLRuntime()
        : m_hr(::WinMLInitialize())
    {
        Ort::InitApi(OrtGetApiBase()->GetApi(ORT_API_VERSION));
    }

    WinMLRuntime::~WinMLRuntime()
    {
        if (SUCCEEDED(m_hr))
        {
            ::WinMLUninitialize();
        }
    }
}

#pragma once

#include <windows.h>

#define WINMLBOOTSTRAP_API

#if defined(__cplusplus)
extern "C"
{
#endif

    /**
     * Initializes the WinML runtime and adds dependencies to the current process.
     * This function must be called before using any WinML APIs.
     *
     * @return HRESULT S_OK on success, an error code otherwise.
     */
    WINMLBOOTSTRAP_API HRESULT WinMLInitialize(void);

    /**
     * Uninitializes the WinML runtime and removes any dependencies in the current process.
     * This function must be called before the process exits.
     *
     * @return No return value.
     */
    WINMLBOOTSTRAP_API void WinMLUninitialize(void);

    namespace Microsoft::Windows::AI::MachineLearning
    {
        class WinMLRuntime
        {
            HRESULT m_hr{S_OK};

        public:
            WinMLRuntime();
            ~WinMLRuntime();

            [[nodiscard]]
            HRESULT GetHResult() const noexcept
            {
                return m_hr;
            }
        };
    }

#if defined(__cplusplus)
}
#endif

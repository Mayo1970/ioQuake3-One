if(NOT BUILD_CLIENT)
    return()
endif()

include(utils/add_git_dependency)
include(utils/set_output_dirs)
include(shared_sources)

include(renderer_common)

set(CLIENT_SOURCES
    ${SOURCE_DIR}/client/cl_cgame.c
    ${SOURCE_DIR}/client/cl_cin.c
    ${SOURCE_DIR}/client/cl_console.c
    ${SOURCE_DIR}/client/cl_input.c
    ${SOURCE_DIR}/client/cl_keys.c
    ${SOURCE_DIR}/client/cl_main.c
    ${SOURCE_DIR}/client/cl_net_chan.c
    ${SOURCE_DIR}/client/cl_parse.c
    ${SOURCE_DIR}/client/cl_scrn.c
    ${SOURCE_DIR}/client/cl_ui.c
    ${SOURCE_DIR}/client/cl_avi.c
    ${SOURCE_DIR}/client/libmumblelink.c
    ${SOURCE_DIR}/client/snd_altivec.c
    ${SOURCE_DIR}/client/snd_adpcm.c
    ${SOURCE_DIR}/client/snd_dma.c
    ${SOURCE_DIR}/client/snd_mem.c
    ${SOURCE_DIR}/client/snd_mix.c
    ${SOURCE_DIR}/client/snd_wavelet.c
    ${SOURCE_DIR}/client/snd_main.c
    ${SOURCE_DIR}/client/snd_codec.c
    ${SOURCE_DIR}/client/snd_codec_wav.c
    ${SOURCE_DIR}/client/snd_codec_ogg.c
    ${SOURCE_DIR}/client/snd_codec_opus.c
    ${SOURCE_DIR}/client/qal.c
    ${SOURCE_DIR}/client/snd_openal.c
    ${SOURCE_DIR}/sdl/sdl_input.c
    ${SOURCE_DIR}/sdl/sdl_snd.c
    ${CLIENT_PLATFORM_SOURCES}
)

add_git_dependency(${SOURCE_DIR}/client/cl_console.c)

set(CLIENT_BINARY ${CLIENT_NAME})

list(APPEND CLIENT_DEFINITIONS BOTLIB)

if(BUILD_STANDALONE)
    list(APPEND CLIENT_DEFINITIONS STANDALONE)
endif()

if(USE_RENDERER_DLOPEN)
    list(APPEND CLIENT_DEFINITIONS USE_RENDERER_DLOPEN)
endif()

if(USE_HTTP AND NOT BUILD_UWP_LIB)
    list(APPEND CLIENT_DEFINITIONS USE_HTTP)
endif()

if(USE_VOIP AND NOT BUILD_UWP_LIB)
    # UWP capture device opens block on a microphone privacy prompt.
    list(APPEND CLIENT_DEFINITIONS USE_VOIP)
endif()

if(USE_MUMBLE)
    list(APPEND CLIENT_DEFINITIONS USE_MUMBLE)
    list(APPEND CLIENT_LIBRARY_SOURCES ${SOURCE_DIR}/client/libmumblelink.c)
endif()

list(APPEND CLIENT_BINARY_SOURCES
    ${SERVER_SOURCES}
    ${CLIENT_SOURCES}
    ${COMMON_SOURCES}
    ${BOTLIB_SOURCES}
    ${SYSTEM_SOURCES}
    ${ASM_SOURCES}
    ${CLIENT_ASM_SOURCES}
    ${CLIENT_LIBRARY_SOURCES})

add_executable(${CLIENT_BINARY} ${CLIENT_EXECUTABLE_OPTIONS} ${CLIENT_BINARY_SOURCES})

target_include_directories(     ${CLIENT_BINARY} PRIVATE ${CLIENT_INCLUDE_DIRS})
target_compile_definitions(     ${CLIENT_BINARY} PRIVATE ${CLIENT_DEFINITIONS})
target_compile_options(         ${CLIENT_BINARY} PRIVATE ${CLIENT_COMPILE_OPTIONS})
target_link_libraries(          ${CLIENT_BINARY} PRIVATE ${COMMON_LIBRARIES} ${CLIENT_LIBRARIES})
target_link_options(            ${CLIENT_BINARY} PRIVATE ${CLIENT_LINK_OPTIONS})

set_output_dirs(${CLIENT_BINARY})

# UWP libioquake3.dll: SDL_main is the one export the MSVC uwp.exe needs.
option(BUILD_UWP_LIB "Build libioquake3.dll for UWP packaging" OFF)

# Verbose UWP diagnostics (boot breadcrumbs, per-shader progress, qconsole.log).
# Default OFF — only ioq3_error.log is written on Com_Error.
option(IOQ3_UWP_DEBUG_LOGS "Enable verbose UWP diagnostics" OFF)

if(BUILD_UWP_LIB)
    set(UWP_LIB_NAME libioquake3)

    # One-symbol .def. --export-all-symbols on this DLL produces a corrupt PE
    # export table (every RVA collapses to the same bogus value).
    set(UWP_DEF_FILE "${CMAKE_CURRENT_BINARY_DIR}/libioquake3_uwp.def")
    file(WRITE "${UWP_DEF_FILE}" "LIBRARY libioquake3\nEXPORTS\n    SDL_main\n")

    add_library(${UWP_LIB_NAME} SHARED ${CLIENT_BINARY_SOURCES} ${UWP_DEF_FILE})
    # LTO hides SDL_main inside .gnu.lto_* sections so the .def can't link it.
    set_target_properties(${UWP_LIB_NAME} PROPERTIES INTERPROCEDURAL_OPTIMIZATION FALSE)
    target_include_directories( ${UWP_LIB_NAME} PRIVATE ${CLIENT_INCLUDE_DIRS})
    set(UWP_LIB_DEFS ${CLIENT_DEFINITIONS} IOQ3_UWP)
    if(IOQ3_UWP_DEBUG_LOGS)
        list(APPEND UWP_LIB_DEFS IOQ3_UWP_DEBUG_LOGS)
    endif()
    target_compile_definitions( ${UWP_LIB_NAME} PRIVATE ${UWP_LIB_DEFS})
    target_compile_options(     ${UWP_LIB_NAME} PRIVATE ${CLIENT_COMPILE_OPTIONS})
    # winmm/psapi aren't allowed in the UWP AppContainer.
    set(UWP_COMMON_LIBS ${COMMON_LIBRARIES})
    list(REMOVE_ITEM UWP_COMMON_LIBS winmm psapi)
    target_link_libraries(      ${UWP_LIB_NAME} PRIVATE ${UWP_COMMON_LIBS} ${CLIENT_LIBRARIES})
    # GNU ld corrupts the export table on this DLL; use lld.
    target_link_options(        ${UWP_LIB_NAME} PRIVATE ${CLIENT_LINK_OPTIONS} "-fuse-ld=lld")
    set_output_dirs(${UWP_LIB_NAME})
    set_target_properties(${UWP_LIB_NAME} PROPERTIES PREFIX "" OUTPUT_NAME "libioquake3")
endif()

if(NOT USE_RENDERER_DLOPEN)
    target_sources(${CLIENT_BINARY} PRIVATE
        # These are never simultaneously populated
        ${RENDERER_GL1_BINARY_SOURCES}
        ${RENDERER_GL2_BINARY_SOURCES})

    target_include_directories( ${CLIENT_BINARY} PRIVATE ${RENDERER_INCLUDE_DIRS})
    target_compile_definitions( ${CLIENT_BINARY} PRIVATE ${RENDERER_DEFINITIONS})
    target_compile_options(     ${CLIENT_BINARY} PRIVATE ${RENDERER_COMPILE_OPTIONS})
    target_link_libraries(      ${CLIENT_BINARY} PRIVATE ${RENDERER_LIBRARIES})
endif()

foreach(LIBRARY IN LISTS CLIENT_DEPLOY_LIBRARIES)
    add_custom_command(TARGET ${CLIENT_BINARY} POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy
            ${LIBRARY}
            $<TARGET_FILE_DIR:${CLIENT_BINARY}>)

    install(FILES ${LIBRARY} DESTINATION
        # install() requires a relative path hence:
        $<PATH:RELATIVE_PATH,$<TARGET_FILE_DIR:${CLIENT_BINARY}>,${CMAKE_BINARY_DIR}/$<CONFIG>>)
endforeach()

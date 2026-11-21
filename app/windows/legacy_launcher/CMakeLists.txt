# paper_agent.exe: the name an install from before the rename (up to b2901) starts, from its updater and its Start
# menu shortcut (rfc/054). It starts the app and ends. Deleted with lib/core/platform/renamed_data.dart once no such
# install remains; it is installed beside the app by ../CMakeLists.txt.
add_executable(paper_agent WIN32 "main.cpp" "launcher.rc")
apply_standard_settings(paper_agent)
target_compile_definitions(paper_agent PRIVATE "APP_EXE=L\"${BINARY_NAME}.exe\"")

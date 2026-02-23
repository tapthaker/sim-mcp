load("@rules_swift//swift:swift.bzl", "swift_library")
load("@rules_apple//apple:macos.bzl", "macos_command_line_application")

swift_library(
    name = "MCPServerLib",
    srcs = glob(["Sources/**/*.swift"]),
    module_name = "MCPServerLib",
)

macos_command_line_application(
    name = "sim-mcp",
    minimum_os_version = "13.0",
    deps = [":MCPServerLib"],
    visibility = ["//visibility:public"],
)

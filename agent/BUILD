load("@rules_swift//swift:swift.bzl", "swift_library")
load("@rules_apple//apple:ios.bzl", "ios_application", "ios_ui_test")

swift_library(
    name = "HostAppLib",
    srcs = glob(["HostApp/Sources/**/*.swift"]),
    module_name = "HostAppLib",
)

ios_application(
    name = "HostApp",
    bundle_id = "com.simulator-mcp.HostApp",
    families = ["iphone", "ipad"],
    infoplists = ["HostApp/Info.plist"],
    minimum_os_version = "16.0",
    deps = [":HostAppLib"],
    visibility = ["//visibility:public"],
)

swift_library(
    name = "AgentTestLib",
    testonly = True,
    srcs = glob(["Sources/**/*.swift"]),
    module_name = "AgentTestLib",
    deps = [":HostAppLib"],
)

ios_ui_test(
    name = "AgentTest",
    minimum_os_version = "16.0",
    test_host = ":HostApp",
    deps = [":AgentTestLib"],
    visibility = ["//visibility:public"],
)

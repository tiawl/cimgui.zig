const std = @import("std");
const toolbox = @import("toolbox");

pub const flags_size: usize = 16;

pub const Paths = struct {
    __dcimgui: []const u8 = undefined,
    __backends: []const u8 = undefined,
    __tmp: []const u8 = undefined,

    pub fn getDcimgui(self: @This()) []const u8 {
        return self.__dcimgui;
    }

    pub fn getBackends(self: @This()) []const u8 {
        return self.__backends;
    }

    pub fn getTmp(self: @This()) []const u8 {
        return self.__tmp;
    }

    pub fn init() !@This() {
        const dcimgui_path = try toolbox.instance().ptrBuilder().build_root.join(toolbox.instance().ptrBuilder().allocator, &.{
            "dcimgui",
        });

        return .{
            .__dcimgui = dcimgui_path,
            .__backends = toolbox.instance().ptrBuilder().pathJoin(&.{
                dcimgui_path, "backends",
            }),
            .__tmp = try toolbox.instance().ptrBuilder().build_root.join(toolbox.instance().ptrBuilder().allocator, &.{
                "tmp",
            }),
        };
    }
};

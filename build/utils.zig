const std = @import("std");
const toolbox_pkg = @import("toolbox");
const Toolbox = toolbox_pkg.Toolbox;

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

    pub fn init(toolbox: *Toolbox) !@This() {
        const dcimgui_path = try toolbox.buildRootJoin(&.{
            "dcimgui",
        });

        return .{
            .__dcimgui = dcimgui_path,
            .__backends = toolbox.pathJoin(&.{
                dcimgui_path, "backends",
            }),
            .__tmp = try toolbox.buildRootJoin(&.{
                "tmp",
            }),
        };
    }
};

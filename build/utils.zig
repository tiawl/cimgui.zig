const std = @import("std");
const toolbox_pkg = @import("toolbox");
const Toolbox = toolbox_pkg.Toolbox;

pub const flags_size: usize = 16;

pub const Paths = struct {
    __dcimgui: []const u8 = undefined,
    __dcimgui_master: []const u8 = undefined,
    __dcimgui_docking: []const u8 = undefined,
    __backends_master: []const u8 = undefined,
    __backends_docking: []const u8 = undefined,
    __tmp: []const u8 = undefined,

    pub fn getDcimgui(self: @This(), docking: ?bool) []const u8 {
        if (docking) |d| {
            return if (d) self.getDcimguiDocking() else self.getDcimguiMaster();
        }
        return self.__dcimgui;
    }

    fn getDcimguiMaster(self: @This()) []const u8 {
        return self.__dcimgui_master;
    }

    fn getDcimguiDocking(self: @This()) []const u8 {
        return self.__dcimgui_docking;
    }

    pub fn getBackends(self: @This(), docking: bool) []const u8 {
        return if (docking) self.getBackendsDocking() else self.getBackendsMaster();
    }

    fn getBackendsMaster(self: @This()) []const u8 {
        return self.__backends_master;
    }

    fn getBackendsDocking(self: @This()) []const u8 {
        return self.__backends_docking;
    }

    pub fn getTmp(self: @This()) []const u8 {
        return self.__tmp;
    }

    pub fn init(toolbox: *Toolbox) !@This() {
        const dcimgui_path = try toolbox.buildRootJoin(&.{
            "dcimgui",
        });

        const dcimgui_master_path = toolbox.pathJoin(&.{
            dcimgui_path, "master",
        });

        const dcimgui_docking_path = toolbox.pathJoin(&.{
            dcimgui_path, "docking",
        });

        return .{
            .__dcimgui = dcimgui_path,
            .__dcimgui_master = dcimgui_master_path,
            .__dcimgui_docking = dcimgui_docking_path,
            .__backends_master = toolbox.pathJoin(&.{
                dcimgui_master_path, "backends",
            }),
            .__backends_docking = toolbox.pathJoin(&.{
                dcimgui_docking_path, "backends",
            }),
            .__tmp = try toolbox.buildRootJoin(&.{
                "tmp",
            }),
        };
    }
};

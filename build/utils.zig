const std = @import ("std");

pub const flags_size: usize = 16;

pub const Paths = struct
{
  // prefixed attributes
  __cimgui: [] const u8 = undefined,
  __backends: [] const u8 = undefined,
  __tmp: [] const u8 = undefined,

  // mandatory getters
  pub fn getCimgui (self: @This ()) [] const u8 { return self.__cimgui; }
  pub fn getBackends (self: @This ()) [] const u8 { return self.__backends; }
  pub fn getTmp (self: @This ()) [] const u8 { return self.__tmp; }

  // mandatory init
  pub fn init (builder: *std.Build) !@This ()
  {
    var self = @This () {
      .__cimgui = try builder.build_root.join (builder.allocator,
        &.{ "cimgui", }),
      .__tmp = try builder.build_root.join (builder.allocator,
        &.{ "tmp", }),
    };

    self.__backends = try std.fs.path.join (builder.allocator,
      &.{ self.getCimgui (), "backends", });

    return self;
  }
};

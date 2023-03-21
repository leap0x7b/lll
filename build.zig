const std = @import("std");

pub fn build(b: *std.Build) !void {
    var target = std.zig.CrossTarget{
        .cpu_arch = .x86,
        .os_tag = .freestanding,
        .abi = .none,
    };

    const features = std.Target.x86.Feature;
    target.cpu_features_sub.addFeature(@enumToInt(features.mmx));
    target.cpu_features_sub.addFeature(@enumToInt(features.sse));
    target.cpu_features_sub.addFeature(@enumToInt(features.sse2));
    target.cpu_features_sub.addFeature(@enumToInt(features.avx));
    target.cpu_features_sub.addFeature(@enumToInt(features.avx2));
    target.cpu_features_add.addFeature(@enumToInt(features.soft_float));

    const optimize = b.standardOptimizeOption(.{});
    const exe_options = b.addOptions();
    const panic_fn = b.option(bool, "panic_fn", "Implement a panic function (could make the bootloader slightly bigger)") orelse false;
    exe_options.addOption(bool, "panic_fn", panic_fn);

    const exe = b.addExecutable(.{
        .name = "lll",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.strip = true;
    exe.code_model = .kernel;
    exe.addOptions("build_options", exe_options);
    exe.setLinkerScriptPath(.{ .path = "src/linker.ld" });

    const nasm_dep = b.dependency("nasm", .{
        .optimize = .ReleaseFast,
    });
    const nasm_exe = nasm_dep.artifact("nasm");

    const nasm_sources = [_][]const u8{
        "src/stage1.s",
        "src/real.s",
    };

    for (nasm_sources) |input_file| {
        const output_basename = basenameNewExtension(b, input_file, ".o");
        const nasm_run = b.addRunArtifact(nasm_exe);

        nasm_run.addArgs(&.{
            "-f",
            "elf32",
            "-g",
            "-F",
            "dwarf",
        });

        nasm_run.addArgs(&.{"-o"});
        exe.addObjectFileSource(nasm_run.addOutputFileArg(output_basename));

        nasm_run.addFileSourceArg(.{ .path = input_file });
    }

    exe.install();

    const bin = exe.addObjCopy(.{
        .basename = "lll.bin",
        .format = .bin,
    });
    const install_bin = b.addInstallBinFile(bin.getOutputSource(), bin.basename);
    b.default_step.dependOn(&install_bin.step);
}

fn basenameNewExtension(b: *std.Build, path: []const u8, new_extension: []const u8) []const u8 {
    const basename = std.fs.path.basename(path);
    const ext = std.fs.path.extension(basename);
    return b.fmt("{s}{s}", .{ basename[0 .. basename.len - ext.len], new_extension });
}

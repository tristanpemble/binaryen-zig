const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const assertions = b.option(bool, "assertions", "Enable assertions (default true in debug builds)") orelse (optimize == .Debug);
    const dwarf = b.option(bool, "dwarf", "Enable full DWARF support") orelse true;

    const origin_dep = b.dependency("binaryen", .{});

    const web_target_query = std.Target.Query{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding, // can't use freestanding cuz binaryen
        //.abi = .musl,
        // https://github.com/ziglang/zig/pull/16207
        .cpu_features_add = std.Target.wasm.featureSet(&.{
            .atomics,
            .multivalue,
            .bulk_memory,
        }),
    };

    const web_target = b.resolveTargetQuery(web_target_query);

    const lib = b.addStaticLibrary(.{
        .name = "binaryen",
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("wasm_intrinsics.zig"),
        .single_threaded = false,
    });

    b.getInstallStep().dependOn(&lib.step);

    lib.defineCMacro("BUILD_STATIC_LIBRARY", null);

    if (target.result.isWasm()) {
        lib.shared_memory = true;
        lib.export_memory = true;
        lib.import_memory = true;
    }

    lib.addIncludePath(origin_dep.path("src"));
    lib.addIncludePath(origin_dep.path("third_party/FP16/include"));

    if (dwarf) {
        lib.defineCMacro("BUILD_LLVM_DWARF", null);
        lib.addIncludePath(origin_dep.path("third_party/llvm-project/include"));
    }
    if (!assertions) {
        lib.defineCMacro("NDEBUG", null);
    }

    // TODO: wasm target? Might require emscripten though

    if (target.result.os.tag == .windows) {
        lib.defineCMacro("_GNU_SOURCE", null);
        lib.defineCMacro("__STDC_FORMAT_MACROS", null);
        // TODO: -wl,/stack:8388608
    }

    const flags: []const []const u8 = &.{
        "-std=c++17",

        "-Wall",
        "-Werror",
        "-Wno-unused-parameter",
        "-Wno-omit-frame-pointer",
        "-Wswitch",
        "-Wimplicit-fallthrough",
        "-Wnon-virtual-dtor",

        "-fno-rtti",
        "-fPIC",

        // TODO: remove once this is resolved: https://github.com/WebAssembly/binaryen/pull/2314
        "-Wno-implicit-int-float-conversion",
        "-Wno-unknown-warning-option",

        // FIXME: only needed in release
        "-Wno-unused-but-set-variable",
    };

    lib.addCSourceFiles(.{
        .root = origin_dep.path("."),
        .files = &.{
            "src/ir/debuginfo.cpp",
            "src/ir/drop.cpp",
            "src/ir/effects.cpp",
            "src/ir/eh-utils.cpp",
            "src/ir/export-utils.cpp",
            "src/ir/ExpressionAnalyzer.cpp",
            "src/ir/ExpressionManipulator.cpp",
            "src/ir/intrinsics.cpp",
            "src/ir/LocalGraph.cpp",
            "src/ir/LocalStructuralDominance.cpp",
            "src/ir/lubs.cpp",
            "src/ir/memory-utils.cpp",
            "src/ir/module-splitting.cpp",
            "src/ir/module-utils.cpp",
            "src/ir/names.cpp",
            "src/ir/possible-contents.cpp",
            "src/ir/properties.cpp",
            "src/ir/ReFinalize.cpp",
            "src/ir/return-utils.cpp",
            "src/ir/stack-utils.cpp",
            "src/ir/table-utils.cpp",
            "src/ir/type-updating.cpp",
        },
        .flags = flags,
    });

    lib.addCSourceFiles(.{
        .root = origin_dep.path("."),
        .files = &.{
            "src/asmjs/asm_v_wasm.cpp",
            "src/asmjs/asmangle.cpp",
            "src/asmjs/shared-constants.cpp",
        },
        .flags = flags,
    });

    lib.addCSourceFiles(.{
        .root = origin_dep.path("."),
        .files = &.{
            "src/cfg/Relooper.cpp",
        },
        .flags = flags,
    });

    lib.addCSourceFiles(.{
        .root = origin_dep.path("."),
        .files = &.{
            "src/emscripten-optimizer/optimizer-shared.cpp",
            "src/emscripten-optimizer/parser.cpp",
            "src/emscripten-optimizer/simple_ast.cpp",
        },
        .flags = flags,
    });

    lib.addCSourceFiles(.{
        .files = &.{
            "wasm_intrinsics.cpp",
        },
        .flags = flags,
    });

    lib.addCSourceFiles(.{
        .root = origin_dep.path("."),
        .files = &.{
            "src/passes/AbstractTypeRefining.cpp",
            "src/passes/AlignmentLowering.cpp",
            "src/passes/Asyncify.cpp",
            "src/passes/AvoidReinterprets.cpp",
            "src/passes/CoalesceLocals.cpp",
            "src/passes/CodeFolding.cpp",
            "src/passes/CodePushing.cpp",
            "src/passes/ConstantFieldPropagation.cpp",
            "src/passes/ConstHoisting.cpp",
            "src/passes/DataFlowOpts.cpp",
            "src/passes/DeadArgumentElimination.cpp",
            "src/passes/DeadCodeElimination.cpp",
            "src/passes/DeAlign.cpp",
            "src/passes/DebugLocationPropagation.cpp",
            "src/passes/DeNaN.cpp",
            "src/passes/Directize.cpp",
            "src/passes/DuplicateFunctionElimination.cpp",
            "src/passes/DuplicateImportElimination.cpp",
            "src/passes/DWARF.cpp",
            "src/passes/ExtractFunction.cpp",
            "src/passes/Flatten.cpp",
            "src/passes/FuncCastEmulation.cpp",
            "src/passes/GenerateDynCalls.cpp",
            "src/passes/GlobalEffects.cpp",
            "src/passes/GlobalRefining.cpp",
            "src/passes/GlobalStructInference.cpp",
            "src/passes/GlobalTypeOptimization.cpp",
            "src/passes/GUFA.cpp",
            "src/passes/hash-stringify-walker.cpp",
            "src/passes/Heap2Local.cpp",
            "src/passes/HeapStoreOptimization.cpp",
            "src/passes/I64ToI32Lowering.cpp",
            "src/passes/Inlining.cpp",
            "src/passes/InstrumentLocals.cpp",
            "src/passes/InstrumentMemory.cpp",
            "src/passes/Intrinsics.cpp",
            "src/passes/J2CLItableMerging.cpp",
            "src/passes/J2CLOpts.cpp",
            "src/passes/JSPI.cpp",
            "src/passes/LegalizeJSInterface.cpp",
            "src/passes/LimitSegments.cpp",
            "src/passes/LocalCSE.cpp",
            "src/passes/LocalSubtyping.cpp",
            "src/passes/LogExecution.cpp",
            "src/passes/LoopInvariantCodeMotion.cpp",
            "src/passes/Memory64Lowering.cpp",
            "src/passes/MemoryPacking.cpp",
            "src/passes/MergeBlocks.cpp",
            "src/passes/MergeLocals.cpp",
            "src/passes/MergeSimilarFunctions.cpp",
            "src/passes/Metrics.cpp",
            "src/passes/MinifyImportsAndExports.cpp",
            "src/passes/MinimizeRecGroups.cpp",
            "src/passes/Monomorphize.cpp",
            "src/passes/MultiMemoryLowering.cpp",
            "src/passes/NameList.cpp",
            "src/passes/NameTypes.cpp",
            "src/passes/NoInline.cpp",
            "src/passes/OnceReduction.cpp",
            "src/passes/OptimizeAddedConstants.cpp",
            "src/passes/OptimizeCasts.cpp",
            "src/passes/OptimizeForJS.cpp",
            "src/passes/OptimizeInstructions.cpp",
            "src/passes/Outlining.cpp",
            "src/passes/param-utils.cpp",
            "src/passes/pass.cpp",
            "src/passes/PickLoadSigns.cpp",
            "src/passes/Poppify.cpp",
            "src/passes/PostEmscripten.cpp",
            "src/passes/Precompute.cpp",
            "src/passes/PrintCallGraph.cpp",
            "src/passes/Print.cpp",
            "src/passes/PrintFeatures.cpp",
            "src/passes/PrintFunctionMap.cpp",
            "src/passes/RedundantSetElimination.cpp",
            "src/passes/RemoveImports.cpp",
            "src/passes/RemoveMemory.cpp",
            "src/passes/RemoveNonJSOps.cpp",
            "src/passes/RemoveUnusedBrs.cpp",
            "src/passes/RemoveUnusedModuleElements.cpp",
            "src/passes/RemoveUnusedNames.cpp",
            "src/passes/RemoveUnusedTypes.cpp",
            "src/passes/ReorderFunctions.cpp",
            "src/passes/ReorderGlobals.cpp",
            "src/passes/ReorderLocals.cpp",
            "src/passes/ReReloop.cpp",
            "src/passes/RoundTrip.cpp",
            "src/passes/SafeHeap.cpp",
            "src/passes/SeparateDataSegments.cpp",
            "src/passes/SetGlobals.cpp",
            "src/passes/SignaturePruning.cpp",
            "src/passes/SignatureRefining.cpp",
            "src/passes/SignExtLowering.cpp",
            "src/passes/SimplifyGlobals.cpp",
            "src/passes/SimplifyLocals.cpp",
            "src/passes/Souperify.cpp",
            "src/passes/SpillPointers.cpp",
            "src/passes/SSAify.cpp",
            "src/passes/StackCheck.cpp",
            "src/passes/StringLowering.cpp",
            "src/passes/Strip.cpp",
            "src/passes/StripEH.cpp",
            "src/passes/StripTargetFeatures.cpp",
            "src/passes/Table64Lowering.cpp",
            "src/passes/test_passes.cpp",
            "src/passes/TraceCalls.cpp",
            "src/passes/TranslateEH.cpp",
            "src/passes/TrapMode.cpp",
            "src/passes/TupleOptimization.cpp",
            "src/passes/TypeFinalizing.cpp",
            "src/passes/TypeGeneralizing.cpp",
            "src/passes/TypeMerging.cpp",
            "src/passes/TypeRefining.cpp",
            "src/passes/TypeSSA.cpp",
            "src/passes/Unsubtyping.cpp",
            "src/passes/Untee.cpp",
            "src/passes/Vacuum.cpp",
        },
        .flags = flags,
    });

    lib.addCSourceFiles(.{
        .root = origin_dep.path("."),
        .files = &.{
            "src/support/archive.cpp",
            "src/support/bits.cpp",
            "src/support/colors.cpp",
            //"src/support/command-line.cpp", // We don't build tools so no need for this
            "src/support/debug.cpp",
            "src/support/dfa_minimization.cpp",
            "src/support/file.cpp",
            "src/support/istring.cpp",
            "src/support/json.cpp",
            "src/support/name.cpp",
            "src/support/path.cpp",
            "src/support/safe_integer.cpp",
            "src/support/string.cpp",
            "src/support/suffix_tree.cpp",
            "src/support/suffix_tree_node.cpp",
            "src/support/threads.cpp",
            "src/support/utilities.cpp",
        },
        .flags = flags,
    });

    lib.addCSourceFiles(.{
        .root = origin_dep.path("."),
        .files = &.{
            "src/wasm/literal.cpp",
            "src/wasm/parsing.cpp",
            "src/wasm/wasm-binary.cpp",
            "src/wasm/wasm.cpp",
            "src/wasm/wasm-emscripten.cpp",
            "src/wasm/wasm-interpreter.cpp",
            "src/wasm/wasm-io.cpp",
            "src/wasm/wasm-ir-builder.cpp",
            "src/wasm/wasm-stack.cpp",
            "src/wasm/wasm-stack-opts.cpp",
            "src/wasm/wasm-type.cpp",
            "src/wasm/wasm-type-shape.cpp",
            "src/wasm/wasm-validator.cpp",
        },
        .flags = flags,
    });

    // wasm-debug.cpp includes LLVM header using std::iterator (deprecated in C++17)
    lib.addCSourceFile(.{
        .file = origin_dep.path("src/wasm/wasm-debug.cpp"),
        .flags = extraFlags(b, flags, &.{"-Wno-deprecated-declarations"}),
    });

    if (dwarf) {
        lib.addCSourceFiles(.{
            .root = origin_dep.path("."),
            .files = &.{
                "third_party/llvm-project/Binary.cpp",
                "third_party/llvm-project/ConvertUTF.cpp",
                "third_party/llvm-project/DataExtractor.cpp",
                "third_party/llvm-project/Debug.cpp",
                "third_party/llvm-project/DJB.cpp",
                "third_party/llvm-project/Dwarf.cpp",
                "third_party/llvm-project/dwarf2yaml.cpp",
                "third_party/llvm-project/DWARFAbbreviationDeclaration.cpp",
                "third_party/llvm-project/DWARFAcceleratorTable.cpp",
                "third_party/llvm-project/DWARFAddressRange.cpp",
                "third_party/llvm-project/DWARFCompileUnit.cpp",
                "third_party/llvm-project/DWARFContext.cpp",
                "third_party/llvm-project/DWARFDataExtractor.cpp",
                "third_party/llvm-project/DWARFDebugAbbrev.cpp",
                "third_party/llvm-project/DWARFDebugAddr.cpp",
                "third_party/llvm-project/DWARFDebugAranges.cpp",
                "third_party/llvm-project/DWARFDebugArangeSet.cpp",
                "third_party/llvm-project/DWARFDebugFrame.cpp",
                "third_party/llvm-project/DWARFDebugInfoEntry.cpp",
                "third_party/llvm-project/DWARFDebugLine.cpp",
                "third_party/llvm-project/DWARFDebugLoc.cpp",
                "third_party/llvm-project/DWARFDebugMacro.cpp",
                "third_party/llvm-project/DWARFDebugPubTable.cpp",
                "third_party/llvm-project/DWARFDebugRangeList.cpp",
                "third_party/llvm-project/DWARFDebugRnglists.cpp",
                "third_party/llvm-project/DWARFDie.cpp",
                "third_party/llvm-project/DWARFEmitter.cpp",
                "third_party/llvm-project/DWARFExpression.cpp",
                "third_party/llvm-project/DWARFFormValue.cpp",
                "third_party/llvm-project/DWARFGdbIndex.cpp",
                "third_party/llvm-project/DWARFListTable.cpp",
                "third_party/llvm-project/DWARFTypeUnit.cpp",
                "third_party/llvm-project/DWARFUnit.cpp",
                "third_party/llvm-project/DWARFUnitIndex.cpp",
                "third_party/llvm-project/DWARFVerifier.cpp",
                "third_party/llvm-project/DWARFVisitor.cpp",
                "third_party/llvm-project/DWARFYAML.cpp",
                "third_party/llvm-project/Error.cpp",
                "third_party/llvm-project/ErrorHandling.cpp",
                "third_party/llvm-project/FormatVariadic.cpp",
                "third_party/llvm-project/Hashing.cpp",
                "third_party/llvm-project/LEB128.cpp",
                "third_party/llvm-project/LineIterator.cpp",
                "third_party/llvm-project/MCRegisterInfo.cpp",
                "third_party/llvm-project/MD5.cpp",
                "third_party/llvm-project/MemoryBuffer.cpp",
                "third_party/llvm-project/NativeFormatting.cpp",
                "third_party/llvm-project/ObjectFile.cpp",
                "third_party/llvm-project/obj2yaml_Error.cpp",
                "third_party/llvm-project/Optional.cpp",
                "third_party/llvm-project/Path.cpp",
                "third_party/llvm-project/raw_ostream.cpp",
                "third_party/llvm-project/ScopedPrinter.cpp",
                "third_party/llvm-project/SmallVector.cpp",
                "third_party/llvm-project/SourceMgr.cpp",
                "third_party/llvm-project/StringMap.cpp",
                "third_party/llvm-project/StringRef.cpp",
                "third_party/llvm-project/SymbolicFile.cpp",
                "third_party/llvm-project/Twine.cpp",
                "third_party/llvm-project/UnicodeCaseFold.cpp",
                "third_party/llvm-project/WithColor.cpp",
                "third_party/llvm-project/YAMLParser.cpp", // XXX: needed?
                "third_party/llvm-project/YAMLTraits.cpp",
            },
            .flags = extraFlags(b, flags, &.{
                "-w",
                "-std=c++14",
                "-D_GNU_SOURCE",
                "-D_DEBUG",
                "-D__STDC_CONSTANT_MACROS",
                "-D__STDC_FORMAT_MACROS",
                "-D__STDC_LIMIT_MACROS",
            }),
        });
    }

    lib.addCSourceFile(.{
        .file = origin_dep.path("src/binaryen-c.cpp"),
        .flags = flags,
    });

    lib.linkLibC();
    lib.linkLibCpp();

    b.installArtifact(lib);
    lib.installHeader(origin_dep.path("src/binaryen-c.h"), "binaryen/binaryen.h");
    lib.installHeader(origin_dep.path("src/wasm-delegations.def"), "binaryen/wasm-delegations.def");

    const binaryen_mod = b.addModule("binaryen", .{
        .root_source_file = b.path("binaryen.zig"),
        .single_threaded = false, // NOTE: wasi builds require this
        .target = target,
    });
    binaryen_mod.linkLibrary(lib);
    binaryen_mod.addIncludePath(origin_dep.path("src"));

    const exe = b.addExecutable(.{
        .name = "wasm-test",
        .root_source_file = b.path("./wasm-test.zig"),
        .single_threaded = false,
        .target = web_target,
    });
    exe.root_module.addImport("binaryen", binaryen_mod);
    //exe.linkLibCpp();
    //exe.linkLibrary(lib);

    const tests = b.addTest(.{
        .root_source_file = b.path("test.zig"),
    });
    tests.root_module.addImport("binaryen", binaryen_mod);

    tests.linkLibC();

    b.step("test", "run wrapper library tests").dependOn(&b.addRunArtifact(tests).step);

    b.step("web", "run wrapper library tests").dependOn(&b.addInstallArtifact(exe, .{}).step);
}

fn extraFlags(b: *std.Build, flags: []const []const u8, more: []const []const u8) []const []const u8 {
    return std.mem.concat(b.allocator, []const u8, &.{ flags, more }) catch @panic("OOM");
}

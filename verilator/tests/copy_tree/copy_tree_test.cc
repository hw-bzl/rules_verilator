#include <algorithm>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <map>
#include <memory>
#include <set>
#include <sstream>
#include <string>
#include <system_error>
#include <vector>

#include "gtest/gtest.h"
#include "rules_cc/cc/runfiles/runfiles.h"

namespace {

using rules_cc::cc::runfiles::Runfiles;

std::unique_ptr<Runfiles> runfiles = nullptr;

// Resolved from the test's first argument, `$(rlocationpath ...)` of the tool.
std::string copy_tree_tool = {};

std::string Testdata(const std::string& path) {
  const std::string key =
      "rules_verilator/verilator/tests/copy_tree/testdata/" + path;
  const std::string location = runfiles->Rlocation(key);
  if (location.empty()) {
    ADD_FAILURE() << "no runfile " << key;
  }
  return location;
}

// Quoted alike for sh and cmd.exe.
std::string Quote(const std::string& arg) { return "\"" + arg + "\""; }

std::string ReadFile(const std::string& path) {
  std::ifstream in(path, std::ios::binary);
  if (!in) {
    ADD_FAILURE() << "cannot read " << path;
    return "";
  }
  std::ostringstream out;
  out << in.rdbuf();
  return out.str();
}

std::set<std::string> ListDir(const std::string& path) {
  std::set<std::string> result;
  std::error_code error;
  for (const auto& entry : std::filesystem::directory_iterator(path, error)) {
    result.insert(entry.path().filename().string());
  }
  if (error) {
    ADD_FAILURE() << "cannot list " << path << ": " << error.message();
  }
  return result;
}

// What Bazel compiles from a source tree.
std::set<std::string> ListCpps(const std::string& path) {
  std::set<std::string> result;
  for (const std::string& name : ListDir(path)) {
    if (name.size() > 4 && name.compare(name.size() - 4, 4, ".cpp") == 0) {
      result.insert(name);
    }
  }
  return result;
}

const std::vector<std::string> kClassLists = {
    "VM_CLASSES_FAST", "VM_SUPPORT_FAST", "VM_CLASSES_SLOW", "VM_SUPPORT_SLOW"};

// A classes.mk in Verilator's form, giving `classes` to the class lists that
// have an entry and omitting the variables in `omit`.
std::string ClassesMk(const std::map<std::string, std::string>& classes,
                      const std::set<std::string>& omit) {
  std::string result;
  if (omit.count("VM_PARALLEL_BUILDS") == 0) {
    result += "VM_PARALLEL_BUILDS = 0\n";
  }
  for (const std::string& list : kClassLists) {
    if (omit.count(list) == 0) {
      const auto it = classes.find(list);
      result += list + " += \\\n" +
                (it == classes.end() ? "" : "  " + it->second + " \\\n") + "\n";
    }
  }
  return result;
}

// A Verilator output tree run through the tool as `common.bzl` does.
class CopyTreeTest : public testing::Test {
 protected:
  void SetUp() override {
    const testing::TestInfo* info =
        testing::UnitTest::GetInstance()->current_test_info();
    std::string name =
        std::string(info->test_suite_name()) + "." + info->name();
    std::replace(name.begin(), name.end(), '/', '_');
    root_ = std::string(std::getenv("TEST_TMPDIR")) + "/" + name;
    ASSERT_TRUE(std::filesystem::create_directory(root_));
    ASSERT_TRUE(std::filesystem::create_directory(Gen()));
  }

  std::string Gen() const { return root_ + "/gen"; }
  std::string Src() const { return root_ + "/src"; }
  std::string Hdr() const { return root_ + "/hdr"; }
  std::string Stderr() const { return ReadFile(root_ + "/stderr"); }

  void Write(const std::string& name, const std::string& content) {
    std::ofstream(Gen() + "/" + name, std::ios::binary) << content;
    files_.push_back(name);
  }

  void WriteStubs(const std::vector<std::string>& names) {
    for (const std::string& name : names) {
      Write(name, "// " + name + "\n");
    }
  }

  void CopyFixture(const std::string& path) {
    Write(path.substr(path.find('/') + 1), ReadFile(Testdata(path)));
  }

  // Whether the tool succeeds; its stderr goes to `Stderr()`.
  bool Run() {
    std::string cmd =
        Quote(std::filesystem::path(copy_tree_tool).make_preferred().string()) +
        " " + Quote("--src_output=" + Src()) + " " +
        Quote("--hdr_output=" + Hdr());
    for (const std::string& name : files_) {
      const std::string path = Gen() + "/" + name;
      const std::string ext = name.substr(name.rfind('.'));
      if (ext == ".cpp" || ext == ".h") {
        cmd += " " + Quote("--src=" + path);
      }
      if (ext == ".h") {
        cmd += " " + Quote("--hdr=" + path);
      }
      if (ext == ".mk" && name.find("_classes.mk") != std::string::npos) {
        cmd += " " + Quote("--classes=" + path);
      }
    }
    cmd += " 2> " + Quote(root_ + "/stderr");
#ifdef _WIN32
    // cmd /c strips the first and the last quote of a command that starts
    // with a quote.
    cmd = "\"" + cmd + "\"";
#endif
    return std::system(cmd.c_str()) == 0;
  }

  // Expects the tool to write what `make -f Vadder.mk Vadder__ALL.cpp` wrote
  // into `dir`, for `dir`'s classes.mk and a stub for each class.
  void ExpectUnityBuildMatchesMake(const std::string& dir,
                                   const std::vector<std::string>& classes) {
    CopyFixture(dir + "/Vadder_classes.mk");
    std::vector<std::string> stubs = {"Vadder.h"};
    for (const std::string& c : classes) {
      stubs.push_back(c + ".cpp");
    }
    WriteStubs(stubs);

    ASSERT_TRUE(Run()) << Stderr();

    EXPECT_EQ(ListCpps(Src()), std::set<std::string>({"Vadder__ALL.cpp"}));
    EXPECT_EQ(ReadFile(Src() + "/Vadder__ALL.cpp"),
              ReadFile(Testdata(dir + "/Vadder__ALL.cpp")));
    EXPECT_EQ(ListDir(Hdr()),
              std::set<std::string>(stubs.begin(), stubs.end()));
  }

 private:
  std::string root_ = {};
  std::vector<std::string> files_ = {};
};

// The fixtures and stub names are what this module's Verilator writes with
// `--no-std --cc`: for verilator/tests/adder/adder.sv with
// `--top-module adder --prefix Vadder` and the flags named in each test, and
// for verilator/tests/output_groups/output_groups.sv with
// `--top-module output_groups --prefix Voutput_groups` and that target's vopts.

TEST_F(CopyTreeTest, UnityBuildMatchesMake) {
  ExpectUnityBuildMatchesMake(
      "unity", {"Vadder", "Vadder___024root__0", "Vadder___024root__Slow",
                "Vadder___024root__0__Slow", "Vadder__Syms__Slow"});
}

// `--trace-vcd`, which also fills VM_SUPPORT_FAST.
TEST_F(CopyTreeTest, UnityBuildWithEveryListMatchesMake) {
  ExpectUnityBuildMatchesMake(
      "vcd", {"Vadder", "Vadder___024root__0", "Vadder__Trace__0",
              "Vadder___024root__Slow", "Vadder___024root__0__Slow",
              "Vadder__Syms__Slow", "Vadder__Trace__0__Slow",
              "Vadder__TraceDecls__0__Slow"});
}

TEST_F(CopyTreeTest, OutputGroupsCompileWhatMakeCompiles) {
  // `--output-split 20 --output-groups 2`.
  CopyFixture("groups/Voutput_groups_classes.mk");
  CopyFixture("groups/Voutput_groups_vm_classes_0.cpp");
  CopyFixture("groups/Voutput_groups_vm_classes_1.cpp");
  CopyFixture("groups/Voutput_groups_vm_classes_Slow_0.cpp");
  CopyFixture("groups/Voutput_groups_vm_classes_Slow_1.cpp");
  const std::string root = "Voutput_groups___024root__";
  std::vector<std::string> stubs = {"Voutput_groups.cpp",
                                    root + "Slow.cpp",
                                    "Voutput_groups__Syms__ctor__0__Slow.cpp",
                                    "Voutput_groups__Syms__ctor__1__Slow.cpp",
                                    "Voutput_groups__Syms__ctor__2__Slow.cpp",
                                    "Voutput_groups__Syms__dtor__0__Slow.cpp",
                                    "Voutput_groups__Syms__Slow.cpp",
                                    "Voutput_groups.h"};
  for (int i = 0; i <= 33; ++i) {
    stubs.push_back(root + std::to_string(i) + ".cpp");
  }
  for (int i = 0; i <= 10; ++i) {
    stubs.push_back(root + std::to_string(i) + "__Slow.cpp");
  }
  WriteStubs(stubs);

  ASSERT_TRUE(Run()) << Stderr();

  // `make -f Voutput_groups.mk` builds exactly these as VK_OBJS.
  EXPECT_EQ(
      ListCpps(Src()),
      std::set<std::string>({"Voutput_groups_vm_classes_0.cpp", root + "29.cpp",
                             "Voutput_groups_vm_classes_1.cpp",
                             "Voutput_groups_vm_classes_Slow_0.cpp",
                             "Voutput_groups_vm_classes_Slow_1.cpp",
                             "Voutput_groups__Syms__ctor__0__Slow.cpp",
                             "Voutput_groups__Syms__ctor__1__Slow.cpp",
                             "Voutput_groups__Syms__ctor__2__Slow.cpp",
                             "Voutput_groups__Syms__dtor__0__Slow.cpp",
                             "Voutput_groups__Syms__Slow.cpp"}));
  EXPECT_EQ(ListDir(Hdr()).count("Voutput_groups.cpp"), 1u);
  EXPECT_EQ(ListDir(Hdr()).count(root + "33.cpp"), 1u);
  EXPECT_EQ(ListDir(Hdr()).count(root + "10__Slow.cpp"), 1u);
}

TEST_F(CopyTreeTest, WithoutClassesMkEverySourceCompiles) {
  // `--make json`, which writes no classes.mk.
  WriteStubs({"Vadder.cpp", "Vadder___024root__0.cpp",
              "Vadder___024root__Slow.cpp", "Vadder___024root__0__Slow.cpp",
              "Vadder__Syms__Slow.cpp", "Vadder.h", "Vadder___024root.h",
              "Vadder__Syms.h", "Vadder__pch.h"});

  ASSERT_TRUE(Run()) << Stderr();

  EXPECT_EQ(ListCpps(Src()),
            std::set<std::string>({"Vadder.cpp", "Vadder___024root__0.cpp",
                                   "Vadder___024root__Slow.cpp",
                                   "Vadder___024root__0__Slow.cpp",
                                   "Vadder__Syms__Slow.cpp"}));
  EXPECT_EQ(ListCpps(Hdr()), std::set<std::string>());
}

TEST_F(CopyTreeTest, LibCreateWrapperCompiles) {
  // `--lib-create adder_lib`.
  CopyFixture("lib/Vadder_classes.mk");
  WriteStubs({"adder_lib.cpp", "Vadder.cpp", "Vadder___024root__0.cpp",
              "Vadder___024root__Slow.cpp", "Vadder___024root__0__Slow.cpp",
              "Vadder__Syms__Slow.cpp", "Vadder.h"});

  ASSERT_TRUE(Run()) << Stderr();

  EXPECT_EQ(ListCpps(Src()),
            std::set<std::string>({"Vadder__ALL.cpp", "adder_lib.cpp"}));
}

TEST_F(CopyTreeTest, ProtectLibWrapperCompiles) {
  // `--protect-lib adder_protect --protect-key secret`.
  CopyFixture("protect/Vadder_classes.mk");
  WriteStubs({"adder_protect.cpp", "Vadder.cpp", "Vadder_PSgvBY__0.cpp",
              "Vadder_PSgvBY__Slow.cpp", "Vadder_PSgvBY__0__Slow.cpp",
              "Vadder_PSv8mA__Slow.cpp", "Vadder.h"});

  ASSERT_TRUE(Run()) << Stderr();

  EXPECT_EQ(ListCpps(Src()),
            std::set<std::string>({"Vadder__ALL.cpp", "adder_protect.cpp"}));
}

TEST_F(CopyTreeTest, ContinuationAtEndOfFileFails) {
  Write("Vt_classes.mk", "VM_CLASSES_FAST += \\\n  Vt \\\n");
  WriteStubs({"Vt.cpp"});

  EXPECT_FALSE(Run());
  EXPECT_NE(Stderr().find("ends in a continuation line"), std::string::npos)
      << Stderr();
}

TEST_F(CopyTreeTest, ListedClassWithoutSourceFails) {
  Write("Vt_classes.mk", ClassesMk({{"VM_CLASSES_FAST", "Vt Vmissing"}}, {}));
  WriteStubs({"Vt.cpp"});

  EXPECT_FALSE(Run());
  EXPECT_NE(Stderr().find("lists Vmissing but there is no Vmissing.cpp"),
            std::string::npos)
      << Stderr();
}

TEST_F(CopyTreeTest, SecondClassesMkFails) {
  Write("Vt_classes.mk", "VM_CLASSES_FAST += Vt\n");
  Write("Vu_classes.mk", "VM_CLASSES_FAST += Vu\n");
  WriteStubs({"Vt.cpp", "Vu.cpp"});

  EXPECT_FALSE(Run());
  EXPECT_NE(Stderr().find("Expected at most one --classes"), std::string::npos)
      << Stderr();
}

// Verilator declares each variable even when it lists nothing.
class MissingDeclarationTest : public CopyTreeTest,
                               public testing::WithParamInterface<const char*> {
};

TEST_P(MissingDeclarationTest, Fails) {
  Write("Vt_classes.mk", ClassesMk({{"VM_CLASSES_FAST", "Vt"}}, {GetParam()}));
  WriteStubs({"Vt.cpp"});

  EXPECT_FALSE(Run());
  EXPECT_NE(Stderr().find("does not declare " + std::string(GetParam()) + "\n"),
            std::string::npos)
      << Stderr();
}

INSTANTIATE_TEST_SUITE_P(CopyTreeTest, MissingDeclarationTest,
                         testing::Values("VM_PARALLEL_BUILDS",
                                         "VM_CLASSES_FAST", "VM_SUPPORT_FAST",
                                         "VM_CLASSES_SLOW", "VM_SUPPORT_SLOW"));

TEST_F(CopyTreeTest, EveryMissingDeclarationNamed) {
  Write("Vt_classes.mk",
        ClassesMk({}, {"VM_PARALLEL_BUILDS", "VM_SUPPORT_SLOW"}));
  WriteStubs({"Vt.cpp"});

  EXPECT_FALSE(Run());
  EXPECT_NE(
      Stderr().find("does not declare VM_PARALLEL_BUILDS VM_SUPPORT_SLOW\n"),
      std::string::npos)
      << Stderr();
}

// Each list may be empty, as long as it is declared.
class EmptyListTest : public CopyTreeTest,
                      public testing::WithParamInterface<const char*> {};

TEST_P(EmptyListTest, OthersEmpty) {
  Write("Vt_classes.mk", ClassesMk({{GetParam(), "Vt"}}, {}));
  WriteStubs({"Vt.cpp"});

  ASSERT_TRUE(Run()) << Stderr();

  EXPECT_EQ(ListCpps(Src()), std::set<std::string>({"Vt__ALL.cpp"}));
  EXPECT_EQ(ListDir(Hdr()), std::set<std::string>({"Vt.cpp"}));
}

INSTANTIATE_TEST_SUITE_P(CopyTreeTest, EmptyListTest,
                         testing::Values("VM_CLASSES_FAST", "VM_SUPPORT_FAST",
                                         "VM_CLASSES_SLOW", "VM_SUPPORT_SLOW"));

// Forms and variables Verilator does not write, which make would read
// differently or not at all.
class UnsupportedFormTest : public CopyTreeTest,
                            public testing::WithParamInterface<const char*> {};

TEST_P(UnsupportedFormTest, Fails) {
  Write("Vt_classes.mk", std::string(GetParam()) + "\nVM_CLASSES_FAST += Vt\n");
  WriteStubs({"Vt.cpp"});

  EXPECT_FALSE(Run());
  EXPECT_NE(Stderr().find(" Verilator writes: " + std::string(GetParam())),
            std::string::npos)
      << Stderr();
}

INSTANTIATE_TEST_SUITE_P(
    CopyTreeTest, UnsupportedFormTest,
    testing::Values(
        "VM_PARALLEL_BUILDS=1", "VM_PARALLEL_BUILDS = 1 ",
        "VM_PARALLEL_BUILDS := 1", "VM_PARALLEL_BUILDS ?= 1",
        "VM_PARALLEL_BUILDS = 1 # comment", "VM_PARALLEL_BUILDS = $(PB)",
        "VM_CLASSES_FAST = Vt", "VM_SUPPORT_SLOW := Vt",
        "VM_CLASSES_FAST: += Vt", "VM_CLASSES_FAST += Vt # comment",
        "VM_CLASSES_FAST += $(EXTRA)", "VM_CLASSES_FAST+=Vt",
        "VM_CLASSES_FAST +=\tVt", "  VM_CLASSES_FAST += Vt",
        "export VM_PARALLEL_BUILDS = 1", "override VM_CLASSES_FAST += Vu",
        "unexport VM_PARALLEL_BUILDS", "define VM_SUPPORT_SLOW",
        "$(eval VM_CLASSES_SLOW += Vu)", "ifeq (a,b)", "ifeq(a,b)",
        "ifneq (a,b)", "ifdef X", "ifndef X", "else", "endif", "define X",
        "endef", "export", "override X = 1", "include x.mk", "-include x.mk",
        "sinclude x.mk", ".RECIPEPREFIX = V", "X := VM_CLASSES",
        "$(X)_FAST += Vu", "$(eval $(call f,VM_CLASSES))", "VM_C11 = $(X)",
        "VM_PARALLEL_BUILDS += 1", "VM_C11 = a#b", "VM_C11 =", "Vt = 1",
        "undefine VM_CLASSES_FAST", "vpath %.cpp x", "private X = 1",
        "x: ; @true", "\tifeq (a,b)", "VM_CLASSES_FAST += Vt\tVu",
        "VM_CLASSES_FAST += Vt\vVu", "VM_CLASSES_FAST += Vt;",
        "MAKEFLAGS += VM_PARALLEL_BUILDS=1", "VM_FAST += Vu", "VM_SLOW = Vu",
        "VM_PREFIX = Vu", "VK_OBJS += Vu", "VM_THREADS = 4",
        "VM_SC_TARGET_ARCH = linux-x86_64", "XYZ = 1"));

// A line that does not start with a name is not read as a variable.
class NotANameTest : public CopyTreeTest,
                     public testing::WithParamInterface<const char*> {};

TEST_P(NotANameTest, FormNamed) {
  Write("Vt_classes.mk", std::string(GetParam()) + "\n" +
                             ClassesMk({{"VM_CLASSES_FAST", "Vt"}}, {}));
  WriteStubs({"Vt.cpp", "Vu.cpp"});

  EXPECT_FALSE(Run());
  EXPECT_NE(Stderr().find(": not in the form Verilator writes: " +
                          std::string(GetParam()) + "\n"),
            std::string::npos)
      << Stderr();
}

INSTANTIATE_TEST_SUITE_P(CopyTreeTest, NotANameTest,
                         testing::Values("$(X)_FAST += Vu",
                                         " VM_CLASSES_FAST += Vu",
                                         "VM_CLASSES_FAST+=Vu"));

// `verilated.mk` reads its own variables, such as VM_FAST, unlike this tool.
TEST_F(CopyTreeTest, UnknownVariableNamed) {
  Write("Vt_classes.mk",
        "VM_FAST += Vu\n" + ClassesMk({{"VM_CLASSES_FAST", "Vt"}}, {}));
  WriteStubs({"Vt.cpp", "Vu.cpp"});

  EXPECT_FALSE(Run());
  EXPECT_NE(Stderr().find(
                "VM_FAST is not a variable Verilator writes: VM_FAST += Vu\n"),
            std::string::npos)
      << Stderr();
}

// make would compile such a class once; __ALL.cpp would include it twice.
TEST_F(CopyTreeTest, ClassListedTwiceFails) {
  Write("Vt_classes.mk",
        ClassesMk({{"VM_CLASSES_FAST", "Vt"}, {"VM_SUPPORT_SLOW", "Vt"}}, {}));
  WriteStubs({"Vt.cpp"});

  EXPECT_FALSE(Run());
  EXPECT_NE(Stderr().find("lists Vt more than once: VM_SUPPORT_SLOW += "),
            std::string::npos)
      << Stderr();
}

TEST_F(CopyTreeTest, ClassRepeatedInOneListFails) {
  Write("Vt_classes.mk", ClassesMk({{"VM_CLASSES_FAST", "Vt Vu Vt"}}, {}));
  WriteStubs({"Vt.cpp", "Vu.cpp"});

  EXPECT_FALSE(Run());
  EXPECT_NE(Stderr().find("lists Vt more than once: VM_CLASSES_FAST += "),
            std::string::npos)
      << Stderr();
}

// The other variables Verilator writes are skipped. The fixtures have each.
class OtherVariableTest : public CopyTreeTest,
                          public testing::WithParamInterface<const char*> {};

TEST_P(OtherVariableTest, Ignored) {
  Write("Vt_classes.mk", std::string(GetParam()) + "\n" +
                             ClassesMk({{"VM_CLASSES_FAST", "Vt"}}, {}));
  WriteStubs({"Vt.cpp"});

  ASSERT_TRUE(Run()) << Stderr();

  EXPECT_EQ(ListCpps(Src()), std::set<std::string>({"Vt__ALL.cpp"}));
}

INSTANTIATE_TEST_SUITE_P(
    CopyTreeTest, OtherVariableTest,
    testing::Values("VM_C11 = 1", "VM_TIMING = 1", "VM_COVERAGE = 1",
                    "VM_TRACE = 1", "VM_TRACE_FST = 1", "VM_TRACE_SAIF = 1",
                    "VM_TRACE_VCD = 1", "VM_VPI = 1",
                    "VM_GLOBAL_FAST += \\\n  verilated \\\n",
                    "VM_GLOBAL_SLOW += \\\n"));

// As in `verilated.mk`, only 1 means a parallel build.
TEST_F(CopyTreeTest, ParallelBuildsOtherThanOneIsUnity) {
  std::string mk = ClassesMk({{"VM_CLASSES_FAST", "Vt"}}, {});
  mk.replace(mk.find("= 0"), 3, "= 2");
  Write("Vt_classes.mk", mk);
  WriteStubs({"Vt.cpp"});

  ASSERT_TRUE(Run()) << Stderr();

  EXPECT_EQ(ListCpps(Src()), std::set<std::string>({"Vt__ALL.cpp"}));
}

// make reads a CRLF line as if it ended in LF.
TEST_F(CopyTreeTest, CrlfLinesReadAsMakeReadsThem) {
  std::string mk = ClassesMk({{"VM_CLASSES_FAST", "Vt"}}, {});
  mk.replace(mk.find("= 0"), 3, "= 1");
  for (size_t pos = mk.find('\n'); pos != std::string::npos;
       pos = mk.find('\n', pos + 2)) {
    mk.insert(pos, "\r");
  }
  Write("Vt_classes.mk", mk);
  WriteStubs({"Vt.cpp"});

  ASSERT_TRUE(Run()) << Stderr();

  EXPECT_EQ(ListCpps(Src()), std::set<std::string>({"Vt.cpp"}));
}

TEST_F(CopyTreeTest, CommentNamingVariablesIgnored) {
  Write("Vt_classes.mk", "# VM_PARALLEL_BUILDS = 1 if VM_CLASSES_FAST += x\n" +
                             ClassesMk({{"VM_CLASSES_FAST", "Vt"}}, {}));
  WriteStubs({"Vt.cpp"});

  ASSERT_TRUE(Run()) << Stderr();

  EXPECT_EQ(ListCpps(Src()), std::set<std::string>({"Vt__ALL.cpp"}));
}

// A prefix that contains a variable's name is read like any other.
class PrefixTest : public CopyTreeTest,
                   public testing::WithParamInterface<const char*> {};

TEST_P(PrefixTest, NamedLikeVariable) {
  const std::string prefix = GetParam();
  Write(prefix + "_classes.mk",
        "# See " + prefix + ".mk for the caller.\n# " + prefix + " += x\n" +
            ClassesMk({{"VM_CLASSES_FAST", prefix}}, {}));
  WriteStubs({prefix + ".cpp"});

  ASSERT_TRUE(Run()) << Stderr();

  EXPECT_EQ(ListCpps(Src()), std::set<std::string>({prefix + "__ALL.cpp"}));
}

INSTANTIATE_TEST_SUITE_P(CopyTreeTest, PrefixTest,
                         testing::Values("VVM_CLASSES_FAST",
                                         "VVM_PARALLEL_BUILDS"));

}  // namespace

int main(int argc, char** argv) {
  testing::InitGoogleTest(&argc, argv);
  if (argc != 2) {
    std::cerr << "Usage: " << argv[0] << " <verilator_copy_tree>" << std::endl;
    return 1;
  }
  std::string error = {};
  runfiles.reset(Runfiles::CreateForTest(BAZEL_CURRENT_REPOSITORY, &error));
  if (runfiles == nullptr) {
    std::cerr << error << std::endl;
    return 1;
  }
  copy_tree_tool = runfiles->Rlocation(argv[1]);
  return RUN_ALL_TESTS();
}

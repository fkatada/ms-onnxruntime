// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#include "gtest/gtest.h"
#include "test/providers/provider_test_utils.h"
#include "test/common/tensor_op_test_utils.h"
#include "test/util/include/default_providers.h"

using namespace std;
namespace onnxruntime {
namespace test {

template <typename T>
class InstanceNormalizationOpTest : public ::testing::Test {
};
using InstanceNormalizationOpTestTypes = ::testing::Types<float, MLFloat16>;
TYPED_TEST_SUITE(InstanceNormalizationOpTest, InstanceNormalizationOpTestTypes);

// Disable TensorRT on some of the tests because its parser doesn't support weight as input

TYPED_TEST(InstanceNormalizationOpTest, InstanceNorm) {
  auto run_test = [](bool is_initializer) {
    OpTester test("InstanceNormalization");
    test.AddAttribute("epsilon", 0.3F);

    vector<float> input = {3.1513367F, 9.283596F, 1.4546119F, 5.4617004F,
                           8.519701F, 1.2382338F, 1.7930176F, 5.1099434F,
                           7.9195533F, 7.638727F, 8.065445F, 3.8082376F,

                           2.3667817F, 2.8248506F, 3.7754705F, 5.861325F,
                           5.058735F, 3.2787242F, 3.6843839F, 9.755121F,
                           2.7902672F, 7.3974323F, 8.283609F, 8.488337F};
    vector<int64_t> input_dims = {2, 3, 4};
    test.AddInput<TypeParam>("input", input_dims, GetTypedArray<TypeParam>(input));

    // vector<float> scale = {2.1F, 0.1F, 1.F};
    vector<float> scale = {1.0F, 1.0F, 1.F};
    vector<int64_t> scale_dims = {3};
    test.AddInput<TypeParam>("scale", scale_dims, GetTypedArray<TypeParam>(scale), is_initializer);

    // vector<float> B = {2.3F, 1.5F, 0.F};
    vector<float> B = {0.0F, 0.0F, 0.F};
    vector<int64_t> B_dims = {3};
    test.AddInput<TypeParam>("B", B_dims, GetTypedArray<TypeParam>(B), is_initializer);

    vector<float> expected_output = {-0.56495477F, 1.48930046F, -1.13334329F, 0.20899761F,
                                     1.46688162F, -0.98600774F, -0.79911913F, 0.31824524F,
                                     0.57370438F, 0.42193634F, 0.6525492F, -1.64818992F,

                                     -0.92380346F, -0.60808484F, 0.04711878F, 1.48476953F,
                                     -0.14644464F, -0.82262872F, -0.66852817F, 1.63760153F,
                                     -1.65898662F, 0.27618144F, 0.64840618F, 0.734399F};
    test.AddOutput<TypeParam>("Y", input_dims, GetTypedArray<TypeParam>(expected_output));
#ifdef USE_WEBGPU
    if constexpr (std::is_same<TypeParam, MLFloat16>::value) {
      test.SetOutputTolerance(0.005F, 0.005F);
    }
#endif
    test.Run(OpTester::ExpectResult::kExpectSuccess, "", {kTensorrtExecutionProvider});
  };
  run_test(false);
  run_test(true);
}

TYPED_TEST(InstanceNormalizationOpTest, InstanceNormBatch1) {
  auto run_test = [](bool is_initializer) {
    OpTester test("InstanceNormalization");
    test.AddAttribute("epsilon", 0.3F);

    vector<float> input = {3.1513367F, 9.283596F, 1.4546119F, 5.4617004F,
                           8.519701F, 1.2382338F, 1.7930176F, 5.1099434F,
                           7.9195533F, 7.638727F, 8.065445F, 3.8082376F};
    vector<int64_t> input_dims = {1, 3, 4};
    test.AddInput<TypeParam>("input", input_dims, GetTypedArray<TypeParam>(input));

    vector<float> scale = {1.0F, 1.0F, 1.F};
    vector<int64_t> scale_dims = {3};
    test.AddInput<TypeParam>("scale", scale_dims, GetTypedArray<TypeParam>(scale), is_initializer);

    vector<float> B = {0.0F, 0.0F, 0.F};
    vector<int64_t> B_dims = {3};
    test.AddInput<TypeParam>("B", B_dims, GetTypedArray<TypeParam>(B), is_initializer);

    vector<float> expected_output = {-0.56495477F, 1.48930046F, -1.13334329F, 0.20899761F,
                                     1.46688162F, -0.98600774F, -0.79911913F, 0.31824524F,
                                     0.57370438F, 0.42193634F, 0.6525492F, -1.64818992F};
    test.AddOutput<TypeParam>("Y", input_dims, GetTypedArray<TypeParam>(expected_output));
#ifdef USE_WEBGPU
    if constexpr (std::is_same<TypeParam, MLFloat16>::value) {
      test.SetOutputTolerance(0.005F, 0.005F);
    }
#endif
    test.Run(OpTester::ExpectResult::kExpectSuccess, "", {kTensorrtExecutionProvider});
  };
  run_test(false);
  run_test(true);
}

TEST(InstanceNormalizationOpTest, InstanceNormBatch2) {
  OpTester test("InstanceNormalization");
  test.AddAttribute("epsilon", 0.3F);

  vector<float> input = {3.1513367F, 9.283596F, 1.4546119F, 5.4617004F,
                         8.519701F, 1.2382338F, 1.7930176F, 5.1099434F,
                         7.9195533F, 7.638727F, 8.065445F, 3.8082376F,

                         3.1513367F, 9.283596F, 1.4546119F, 5.4617004F,
                         8.519701F, 1.2382338F, 1.7930176F, 5.1099434F,
                         7.9195533F, 7.638727F, 8.065445F, 3.8082376F};
  vector<int64_t> input_dims = {2, 3, 4};
  test.AddInput<float>("input", input_dims, input);

  vector<float> scale = {1.0F, 1.0F, 1.F};
  vector<int64_t> scale_dims = {3};
  test.AddInput<float>("scale", scale_dims, scale);

  vector<float> B = {0.0F, 0.0F, 0.F};
  vector<int64_t> B_dims = {3};
  test.AddInput<float>("B", B_dims, B);

  vector<float> expected_output = {-0.56495477F, 1.48930046F, -1.13334329F, 0.20899761F,
                                   1.46688162F, -0.98600774F, -0.79911913F, 0.31824524F,
                                   0.57370438F, 0.42193634F, 0.6525492F, -1.64818992F,

                                   -0.56495477F, 1.48930046F, -1.13334329F, 0.20899761F,
                                   1.46688162F, -0.98600774F, -0.79911913F, 0.31824524F,
                                   0.57370438F, 0.42193634F, 0.6525492F, -1.64818992F};

  test.AddOutput<float>("Y", input_dims, expected_output);
  test.Run(OpTester::ExpectResult::kExpectSuccess, "", {kTensorrtExecutionProvider});
}

// Only CUDA and ROCm kernels have float 16 support
#if defined(USE_CUDA) || defined(USE_ROCM) || defined(USE_COREML) || defined(USE_WEBGPU)

TEST(InstanceNormalizationOpTest, InstanceNormBatch1_fp16) {
  OpTester test("InstanceNormalization");
  test.AddAttribute("epsilon", 0.3F);

  vector<float> input = {3.1513367F, 9.283596F, 1.4546119F, 5.4617004F,
                         8.519701F, 1.2382338F, 1.7930176F, 5.1099434F,
                         7.9195533F, 7.638727F, 8.065445F, 3.8082376F};
  vector<int64_t> input_dims = {1, 3, 4};

  vector<float> scale = {1.0F, 1.0F, 1.F};
  vector<int64_t> scale_dims = {3};

  vector<float> B = {0.0F, 0.0F, 0.F};
  vector<int64_t> B_dims = {3};

  vector<float> expected_output = {-0.56495477F, 1.48930046F, -1.13334329F, 0.20899761F,
                                   1.46688162F, -0.98600774F, -0.79911913F, 0.31824524F,
                                   0.57370438F, 0.42193634F, 0.6525492F, -1.64818992F};

  constexpr size_t input_size = 1 * 3 * 4;

  vector<MLFloat16> input_fp16(input_size);
  vector<MLFloat16> scale_fp16(3);
  vector<MLFloat16> B_fp16(3);
  vector<MLFloat16> expected_output_fp16(input_size);

  ConvertFloatToMLFloat16(input.data(), input_fp16.data(), input_size);
  ConvertFloatToMLFloat16(scale.data(), scale_fp16.data(), 3);
  ConvertFloatToMLFloat16(B.data(), B_fp16.data(), 3);
  ConvertFloatToMLFloat16(expected_output.data(), expected_output_fp16.data(), input_size);

  test.AddInput<MLFloat16>("X", input_dims, input_fp16);
  test.AddInput<MLFloat16>("scale", {3}, scale_fp16);
  test.AddInput<MLFloat16>("B", {3}, B_fp16);
  test.AddOutput<MLFloat16>("Y", input_dims, expected_output_fp16);
#ifdef USE_WEBGPU
  test.SetOutputTolerance(0.005F, 0.005F);
#endif
  test.Run(OpTester::ExpectResult::kExpectSuccess, "", {kTensorrtExecutionProvider});
}

TEST(InstanceNormalizationOpTest, InstanceNormBatch2_fp16) {
  OpTester test("InstanceNormalization");
  test.AddAttribute("epsilon", 0.3F);

  vector<float> input = {3.1513367F, 9.283596F, 1.4546119F, 5.4617004F,
                         8.519701F, 1.2382338F, 1.7930176F, 5.1099434F,
                         7.9195533F, 7.638727F, 8.065445F, 3.8082376F,

                         3.1513367F, 9.283596F, 1.4546119F, 5.4617004F,
                         8.519701F, 1.2382338F, 1.7930176F, 5.1099434F,
                         7.9195533F, 7.638727F, 8.065445F, 3.8082376F};
  vector<int64_t> input_dims = {2, 3, 4};

  vector<float> scale = {1.0F, 1.0F, 1.F};
  vector<int64_t> scale_dims = {3};

  vector<float> B = {0.0F, 0.0F, 0.F};
  vector<int64_t> B_dims = {3};

  vector<float> expected_output = {-0.56495477F, 1.48930046F, -1.13334329F, 0.20899761F,
                                   1.46688162F, -0.98600774F, -0.79911913F, 0.31824524F,
                                   0.57370438F, 0.42193634F, 0.6525492F, -1.64818992F,

                                   -0.56495477F, 1.48930046F, -1.13334329F, 0.20899761F,
                                   1.46688162F, -0.98600774F, -0.79911913F, 0.31824524F,
                                   0.57370438F, 0.42193634F, 0.6525492F, -1.64818992F};

  constexpr size_t input_size = 2 * 3 * 4;

  vector<MLFloat16> input_fp16(input_size);
  vector<MLFloat16> scale_fp16(3);
  vector<MLFloat16> B_fp16(3);
  vector<MLFloat16> expected_output_fp16(input_size);

  ConvertFloatToMLFloat16(input.data(), input_fp16.data(), input_size);
  ConvertFloatToMLFloat16(scale.data(), scale_fp16.data(), 3);
  ConvertFloatToMLFloat16(B.data(), B_fp16.data(), 3);
  ConvertFloatToMLFloat16(expected_output.data(), expected_output_fp16.data(), input_size);

  test.AddInput<MLFloat16>("X", input_dims, input_fp16);
  test.AddInput<MLFloat16>("scale", {3}, scale_fp16);
  test.AddInput<MLFloat16>("B", {3}, B_fp16);
  test.AddOutput<MLFloat16>("Y", input_dims, expected_output_fp16);
#ifdef USE_WEBGPU
  test.SetOutputTolerance(0.005F, 0.005F);
#endif
  test.Run(OpTester::ExpectResult::kExpectSuccess, "", {kTensorrtExecutionProvider});
}

#endif
TEST(InstanceNormalizationOpTest, InstanceNorm_2) {
  OpTester test("InstanceNormalization");
  test.AddAttribute("epsilon", 0.3F);

  vector<float> input = {2.676342F, 4.1100464F, 4.570907F,
                         5.8493505F, 4.772751F, 7.1669755F,
                         2.8400702F, 8.903057F, 1.2464883F,
                         7.034208F, 4.755743F, 6.0282083F,
                         2.2634823F, 2.7829134F, 8.206701F,
                         9.7143545F, 3.8208177F, 7.2309036F,
                         8.887503F, 9.05146F, 1.7653979F,
                         1.351493F, 2.5284739F, 8.903282F,
                         1.8851215F, 4.7899685F, 9.621006F,
                         5.7984877F, 7.226894F, 3.8396406F,
                         7.1785083F, 8.511631F, 1.1645945F,
                         7.751299F, 9.89975F, 7.733491F};
  vector<int64_t> input_dims = {2, 3, 2, 1, 3};
  test.AddInput<float>("input", input_dims, input);

  vector<float> scale = {4.753198F, 7.4829206F, 1.0010294F};
  vector<int64_t> scale_dims = {3};
  test.AddInput<float>("scale", scale_dims, scale);

  vector<float> B = {3.720993F, 2.320803F, 1.8310473F};
  vector<int64_t> B_dims = {3};
  test.AddInput<float>("B", B_dims, B);

  vector<float> expected_output = {-3.1855264F, 1.3537457F, 2.8128836F,
                                   6.860582F, 3.451944F, 11.032334F,
                                   -4.252796F, 13.116836F, -8.8181925F,
                                   7.7628374F, 1.2353455F, 4.880785F,
                                   0.6543751F, 0.83380324F, 2.7073524F,
                                   3.2281437F, 1.1923285F, 2.3702807F,
                                   8.316614F, 8.533577F, -1.1079268F,
                                   -1.6556396F, -0.098163605F, 8.337496F,
                                   -8.482306F, 0.1348517F, 14.466003F,
                                   3.1265988F, 7.3639297F, -2.684272F,
                                   1.88028F, 2.353724F, -0.25549555F,
                                   2.0837004F, 2.8466992F, 2.0773761F};
  test.AddOutput<float>("Y", input_dims, expected_output);
  test.Run(OpTester::ExpectResult::kExpectSuccess, "", {kTensorrtExecutionProvider});
}

TEST(InstanceNormalizationOpTest, InstanceNormNCHW) {
  OpTester test("InstanceNormalization");
  test.AddAttribute("epsilon", 0.009999999776482582f);

  vector<float> input = {1.0f, 2.0f, 3.0f, 2.0f, 2.0f, 2.0f};
  vector<int64_t> input_dims = {1, 2, 1, 3};
  test.AddInput<float>("input", input_dims, input);

  vector<float> scale = {1.0f, 1.0f};
  vector<int64_t> scale_dims = {2};
  test.AddInput<float>("scale", scale_dims, scale);

  vector<float> B = {0.0f, 2.0f};
  vector<int64_t> B_dims = {2};
  test.AddInput<float>("B", B_dims, B);

  vector<float> expected_output = {-1.21566f, 0.0f, 1.21566f, 2.0f, 2.0f, 2.0f};
  test.AddOutput<float>("Y", input_dims, expected_output);

  test.Run(OpTester::ExpectResult::kExpectSuccess, "", {
                                                           kTensorrtExecutionProvider,
                                                       });
}

#ifdef USE_WEBGPU
TEST(InstanceNormalizationOpTest, InstanceNormNCHW_webgpu) {
  OpTester test("InstanceNormalization");
  test.AddAttribute("epsilon", 0.009999999776482582f);

  vector<float> input = {1.0f, 2.0f, 3.0f, 2.0f, 2.0f, 2.0f};
  vector<int64_t> input_dims = {1, 2, 1, 3};
  test.AddInput<float>("input", input_dims, input);

  vector<float> scale = {1.0f, 1.0f};
  vector<int64_t> scale_dims = {2};
  test.AddInput<float>("scale", scale_dims, scale);

  vector<float> B = {0.0f, 2.0f};
  vector<int64_t> B_dims = {2};
  test.AddInput<float>("B", B_dims, B);

  vector<float> expected_output = {-1.21566f, 0.0f, 1.21566f, 2.0f, 2.0f, 2.0f};
  test.AddOutput<float>("Y", input_dims, expected_output);

  test.ConfigEp(DefaultWebGpuExecutionProvider(false)).RunWithConfig();
}

TEST(InstanceNormalizationOpTest, InstanceNormNCHW_webgpu_2) {
  OpTester test("InstanceNormalization");
  test.AddAttribute("epsilon", 0.009999999776482582f);

  vector<float> input = {1.0f, 2.0f, 3.0f, 2.0f, 2.0f, 2.0f, 2.0f, 2.0f};
  vector<int64_t> input_dims = {1, 2, 2, 2};
  test.AddInput<float>("input", input_dims, input);

  vector<float> scale = {1.0f, 1.0f};
  vector<int64_t> scale_dims = {2};
  test.AddInput<float>("scale", scale_dims, scale);

  vector<float> B = {0.0f, 2.0f};
  vector<int64_t> B_dims = {2};
  test.AddInput<float>("B", B_dims, B);

  vector<float> expected_output = {-1.40028f, 0.0f, 1.40028f, 0.0f, 2.0f, 2.0f, 2.0f, 2.0f};
  test.AddOutput<float>("Y", input_dims, expected_output);

  test.ConfigEp(DefaultWebGpuExecutionProvider(false)).RunWithConfig();
}
#endif

}  // namespace test
}  // namespace onnxruntime

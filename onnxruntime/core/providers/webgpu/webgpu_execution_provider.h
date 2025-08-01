// Copyright (c) Microsoft Corporation. All rights reserved.
// Copyright (c) 2019, NXP Semiconductor, Inc. All rights reserved.
// Licensed under the MIT License.

#pragma once

#include "core/framework/execution_provider.h"
#include "core/framework/session_options.h"
#include "core/graph/constants.h"
#include "core/providers/providers.h"
#include "core/providers/webgpu/buffer_manager.h"

struct pthreadpool;
namespace onnxruntime {
namespace webgpu {

// forward declaration for this EP's namespace.
template <typename T>
KernelCreateInfo BuildKernelCreateInfo();

class WebGpuContext;
class WebGpuProfiler;
class GpuBufferAllocator;

// Forward declare CapturedCommandInfo which is now defined in webgpu_context.h
struct CapturedCommandInfo;
}  // namespace webgpu

struct WebGpuExecutionProviderConfig {
  WebGpuExecutionProviderConfig(DataLayout data_layout, bool enable_graph_capture, bool enable_pix_capture)
      : data_layout{data_layout},
        enable_graph_capture{enable_graph_capture},
        enable_pix_capture{enable_pix_capture} {}
  WebGpuExecutionProviderConfig(WebGpuExecutionProviderConfig&&) = default;
  WebGpuExecutionProviderConfig& operator=(WebGpuExecutionProviderConfig&&) = default;
  ORT_DISALLOW_COPY_AND_ASSIGNMENT(WebGpuExecutionProviderConfig);

  DataLayout data_layout;
  bool enable_graph_capture;
  bool enable_pix_capture;
  std::vector<std::string> force_cpu_node_names;
};

class WebGpuExecutionProvider : public IExecutionProvider {
 public:
  WebGpuExecutionProvider(int context_id, webgpu::WebGpuContext& context, WebGpuExecutionProviderConfig&& config);
  ~WebGpuExecutionProvider() override;

  std::vector<std::unique_ptr<ComputeCapability>> GetCapability(
      const onnxruntime::GraphViewer& graph_viewer,
      const IKernelLookup& /*kernel_lookup*/,
      const GraphOptimizerRegistry& /* graph_optimizer_registry */,
      IResourceAccountant* /* resource_accountant */) const override;

  std::shared_ptr<KernelRegistry> GetKernelRegistry() const override;
  std::unique_ptr<onnxruntime::IDataTransfer> GetDataTransfer() const override;
#if defined(__wasm__)
  std::unique_ptr<onnxruntime::IExternalDataLoader> GetExternalDataLoader() const override;
#endif

  DataLayout GetPreferredLayout() const override { return preferred_data_layout_; }

  std::optional<bool> ShouldConvertDataLayoutForOp(std::string_view node_domain,
                                                   std::string_view node_op_type,
                                                   DataLayout target_data_layout) const override;

  FusionStyle GetFusionStyle() const override { return FusionStyle::FilteredGraphViewer; }

  // WebGPU EP disallow concurrent run because actual implementation (eg. WebGPU backend) relies on global states to
  // work, and concurrent run with async function may mess up the states and cause undefined behavior.
  bool ConcurrentRunSupported() const override { return false; }

  std::vector<AllocatorPtr> CreatePreferredAllocators() override;
  Status OnSessionInitializationEnd() override;

  Status OnRunStart(const onnxruntime::RunOptions& run_options) override;
  Status OnRunEnd(bool sync_stream, const onnxruntime::RunOptions& run_options) override;

  // WebGPU EP reuses the Device ID as the key to get the WebGpuContext instance.
  int GetDeviceId() const override { return context_id_; }

  std::unique_ptr<profiling::EpProfiler> GetProfiler() override;

  bool IsGraphCaptureEnabled() const override;
  bool IsGraphCaptured(int graph_annotation_id) const override;
  Status ReplayGraph(int graph_annotation_id) override;
  webgpu::BufferManager& BufferManager() const;

 private:
  bool IsGraphCaptureAllowed() const;
  void IncrementRegularRunCountBeforeGraphCapture();

  int context_id_;
  webgpu::WebGpuContext& context_;
  webgpu::WebGpuProfiler* profiler_ = nullptr;
  DataLayout preferred_data_layout_;
  std::vector<std::string> force_cpu_node_names_;
  bool enable_graph_capture_ = false;
  bool is_graph_captured_ = false;
  int regular_run_count_before_graph_capture_ = 0;
  const int min_num_runs_before_cuda_graph_capture_ = 1;  // required min regular runs before graph capture for the necessary memory allocations.
  int m_current_graph_annotation_id = 0;
  webgpu::GpuBufferAllocator* allocator_ = nullptr;

  // Buffer manager specifically for graph capture mode
  std::unique_ptr<webgpu::BufferManager> graph_buffer_mgr_ = nullptr;

  // Store captured commands directly in the EP instead of in WebGpuContext
  std::vector<webgpu::CapturedCommandInfo> captured_commands_;
};

}  // namespace onnxruntime

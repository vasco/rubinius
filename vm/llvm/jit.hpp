#ifndef RBX_LLVM_JIT_HPP
#define RBX_LLVM_JIT_HPP

#include <stdint.h>
#include <unistd.h>

#include <llvm/Module.h>
#include <llvm/DerivedTypes.h>
#include <llvm/Function.h>
#include <llvm/Module.h>
#include <llvm/Instructions.h>
#include <llvm/Support/IRBuilder.h>
#include <llvm/ModuleProvider.h>
#include <llvm/ExecutionEngine/JIT.h>
#include <llvm/CodeGen/MachineCodeInfo.h>
#include <llvm/Pass.h>
#include <llvm/PassManager.h>
#include <llvm/Support/raw_ostream.h>
#include <llvm/LLVMContext.h>

#include "vm.hpp"
#include "vmmethod.hpp"
#include "configuration.hpp"

#include "builtin/machine_method.hpp"
#include "builtin/block_environment.hpp"

#include "instruments/timing.hpp"
#include "object_utils.hpp"

namespace rubinius {

  class InlinePolicy;
  class JITMethodInfo;

  class JITInlineBlock {
    llvm::PHINode* block_break_result_;
    llvm::BasicBlock* block_break_loc_;
    VMMethod* code_;
    JITMethodInfo* scope_;
    int which_;
    bool created_object_;

  public:
    JITInlineBlock(llvm::PHINode* phi, llvm::BasicBlock* brk, VMMethod* code,
                   JITMethodInfo* scope, int which)
      : block_break_result_(phi)
      , block_break_loc_(brk)
      , code_(code)
      , scope_(scope)
      , which_(which)
      , created_object_(false)
    {}

    llvm::PHINode* block_break_result() {
      return block_break_result_;
    }

    llvm::BasicBlock* block_break_loc() {
      return block_break_loc_;
    }

    VMMethod* code() {
      return code_;
    }

    JITMethodInfo* creation_scope() {
      return scope_;
    }

    int which() {
      return which_;
    }

    bool created_object_p() {
      return created_object_;
    }

    void set_created_object() {
      created_object_ = true;
    }
  };

  class JITMethodInfo {
    llvm::Function* function_;
    llvm::BasicBlock* entry_;
    llvm::Value* call_frame_;
    llvm::Value* stack_;
    llvm::Value* vm_;
    llvm::Value* args_;
    llvm::Value* variables_;
    llvm::Value* previous_;
    llvm::Value* profiling_entry_;
    llvm::Value* out_args_;
    llvm::Value* counter_;

    JITMethodInfo* parent_info_;
    JITMethodInfo* creator_info_;

    bool use_full_scope_;

    JITInlineBlock* inline_block_;
    JITInlineBlock* block_info_;

  public:
    VMMethod* vmm;
    bool is_block;
    llvm::BasicBlock* inline_return;
    llvm::Value* return_value;
    InlinePolicy* inline_policy;
    llvm::BasicBlock* fin_block;
    int called_args;
    std::vector<llvm::Value*>* stack_args;

    JITMethodInfo* root;

  public:
    JITMethodInfo(VMMethod* v, JITMethodInfo* parent = 0)
      : function_(0)
      , entry_(0)
      , call_frame_(0)
      , stack_(0)
      , vm_(0)
      , args_(0)
      , previous_(0)
      , profiling_entry_(0)
      , out_args_(0)
      , counter_(0)
      , parent_info_(parent)
      , creator_info_(0)
      , use_full_scope_(false)
      , inline_block_(0)
      , block_info_(0)
      , vmm(v)
      , is_block(false)
      , inline_return(0)
      , return_value(0)
      , inline_policy(0)
      , fin_block(0)
      , called_args(-1)
      , stack_args(0)
      , root(0)
    {}

    void set_function(llvm::Function* func) {
      function_ = func;
    }

    llvm::Function* function() {
      return function_;
    }

    void set_vm(llvm::Value* vm) {
      vm_ = vm;
    }

    llvm::Value* vm() {
      return vm_;
    }

    void set_args(llvm::Value* args) {
      args_ = args;
    }

    llvm::Value* args() {
      return args_;
    }

    void set_previous(llvm::Value* prev) {
      previous_ = prev;
    }

    llvm::Value* previous() {
      return previous_;
    }

    void set_profiling_entry(llvm::Value* val) {
      profiling_entry_ = val;
    }

    llvm::Value* profiling_entry() {
      return profiling_entry_;
    }

    void set_entry(llvm::BasicBlock* entry) {
      entry_ = entry;
    }

    llvm::BasicBlock* entry() {
      return entry_;
    }

    void set_call_frame(llvm::Value* val) {
      call_frame_ = val;
    }

    llvm::Value* call_frame() {
      return call_frame_;
    }

    void set_stack(llvm::Value* val) {
      stack_ = val;
    }

    llvm::Value* stack() {
      return stack_;
    }

    void set_variables(llvm::Value* vars) {
      variables_ = vars;
    }

    llvm::Value* variables() {
      return variables_;
    }

    void set_parent_info(JITMethodInfo& info) {
      parent_info_ = &info;
      function_ = info.function();
      vm_ = info.vm();
      out_args_ = info.out_args();
      counter_ = info.counter();
    }

    llvm::Value* parent_call_frame() {
      if(parent_info_) {
        return parent_info_->call_frame();
      }

      return 0;
    }

    JITMethodInfo* parent_info() {
      return parent_info_;
    }

    JITMethodInfo* creator_info() {
      return creator_info_;
    }

    void set_creator_info(JITMethodInfo* creator_info) {
      creator_info_ = creator_info;
    }

    JITMethodInfo* home_info() {
      JITMethodInfo* nfo = creator_info_;
      if(!nfo) return 0;

      while(JITMethodInfo* nxt = nfo->creator_info()) {
        nfo = nxt;
      }

      return nfo;
    }

    JITInlineBlock* inline_block() {
      return inline_block_;
    }

    void set_inline_block(JITInlineBlock* bi) {
      inline_block_ = bi;
    }

    void clear_inline_block() {
      inline_block_ = 0;
    }
    
    void set_block_info(JITInlineBlock* block) {
      block_info_ = block;
    }

    JITInlineBlock* block_info() {
      return block_info_;
    }

    llvm::BasicBlock* block_break_loc() {
      return block_info_->block_break_loc();
    }

    llvm::PHINode* block_break_result() {
      return block_info_->block_break_result();
    }

    void set_out_args(llvm::Value* out_args) {
      out_args_ = out_args;
    }

    llvm::Value* out_args() {
      return out_args_;
    }

    bool use_full_scope() {
      return use_full_scope_;
    }

    void set_use_full_scope() {
      use_full_scope_ = true;
    }

    llvm::Value* counter() {
      return counter_;
    }

    void set_counter(llvm::Value* counter) {
      counter_ = counter;
    }

    llvm::AllocaInst* create_alloca(const llvm::Type* type, llvm::Value* size = 0,
                                    const llvm::Twine& name = "");

  };

  struct JITBasicBlock {
    llvm::BasicBlock* block;
    int sp;
    int start_ip;
    int end_ip;
    bool reachable;
    bool landing_pad;

  public:
    JITBasicBlock()
      : block(0)
      , sp(-1)
      , start_ip(0)
      , end_ip(0)
      , reachable(false)
      , landing_pad(false)
    {}
  };

  typedef std::map<int, JITBasicBlock> BlockMap;

  enum JitDebug {
    cSimple = 1,
    cOptimized = 2,
    cMachineCode = 4
  };

  class BlockEnvironment;

  class BackgroundCompilerThread;

  class LLVMState {
    llvm::LLVMContext& ctx_;
    llvm::Module* module_;
    llvm::ExistingModuleProvider* mp_;
    llvm::ExecutionEngine* engine_;
    llvm::FunctionPassManager* passes_;

    const llvm::Type* object_;
    Configuration& config_;

    BackgroundCompilerThread* background_thread_;
    GlobalLock& global_lock_;
    SymbolTable& symbols_;

    int jitted_methods_;
    int queued_methods_;
    int accessors_inlined_;
    int uncommons_taken_;

    SharedState& shared_;

    bool include_profiling_;
    llvm::GlobalVariable* profiling_;

    int code_bytes_;

  public:

    uint64_t time_spent;

    const llvm::Type* VoidTy;

    const llvm::Type* Int1Ty;
    const llvm::Type* Int8Ty;
    const llvm::Type* Int16Ty;
    const llvm::Type* Int32Ty;
    const llvm::Type* Int64Ty;
    const llvm::Type* IntPtrTy;

    const llvm::Type* FloatTy;
    const llvm::Type* DoubleTy;

    static LLVMState* get(STATE);
    static void shutdown(STATE);
    static void on_fork(STATE);
    static void pause(STATE);
    static void unpause(STATE);

    LLVMState(STATE);
    void add_internal_functions();

    int jit_dump_code() {
      return config_.jit_dump_code;
    }

    Configuration& config() {
      return config_;
    }

    GlobalLock& global_lock() {
      return global_lock_;
    }

    llvm::GlobalVariable* profiling() {
      return profiling_;
    }

    bool include_profiling() {
      return include_profiling_;
    }

    llvm::Module* module() { return module_; }
    llvm::ExecutionEngine* engine() { return engine_; }
    llvm::FunctionPassManager* passes() { return passes_; }
    const llvm::Type* object() { return object_; }

    int jitted_methods() {
      return jitted_methods_;
    }

    int queued_methods() {
      return queued_methods_;
    }

    int add_jitted_method() {
      return ++jitted_methods_;
    }

    int code_bytes() {
      return code_bytes_;
    }

    void add_code_bytes(int bytes) {
      code_bytes_ += bytes;
    }

    void add_accessor_inlined() {
      accessors_inlined_++;
    }

    int accessors_inlined() {
      return accessors_inlined_;
    }

    void add_uncommons_taken() {
      uncommons_taken_++;
    }

    int uncommons_taken() {
      return uncommons_taken_;
    }

    SharedState& shared() { return shared_; }

    llvm::LLVMContext& ctx() { return ctx_; }

    const llvm::Type* ptr_type(std::string name);
    const llvm::Type* type(std::string name);

    void compile_soon(STATE, VMMethod* vmm, BlockEnvironment* block=0);
    void remove(llvm::Function* func);

    VMMethod* find_candidate(VMMethod* start, CallFrame* call_frame);
    void compile_callframe(STATE, VMMethod* start, CallFrame* call_frame,
                           int primitive = -1);

    Symbol* symbol(const char* sym);
    const char* symbol_cstr(const Symbol* sym);

    void shutdown_i();
    void on_fork_i();
    void pause_i();
    void unpause_i();

    static void show_machine_code(void* impl, size_t bytes);
  };

  class LLVMCompiler {
    llvm::Function* function_;
    llvm::MachineCodeInfo* mci_;

  public:
    LLVMCompiler()
      : function_(0)
      , mci_(0)
    {}

    ~LLVMCompiler() {
      delete mci_;
    }

    int code_bytes() {
      return mci_->size();
    }

    llvm::Function* llvm_function() {
      return function_;
    }

    void initialize_call_frame(llvm::Function* func,
      llvm::BasicBlock* block, llvm::Value* call_frame,
      int stack_size, llvm::Value* stack, llvm::Value* vars);

    void compile(LLVMState*, VMMethod* vmm, bool is_block=false);
    void* function_pointer(STATE);
    void* function_pointer();
    llvm::Function* llvm_function(STATE);
    void show_assembly(STATE);
    void* generate_function(LLVMState* ls);
    void show_machine_code();

    void import_args(LLVMState* ls, llvm::Function* func,
                   llvm::BasicBlock*& block, VMMethod* vmm,
                   llvm::Value* vars, llvm::Value* call_frame);
  };

  class Signature {
  protected:
    LLVMState* ls_;
    std::vector<const llvm::Type*> types_;
    const llvm::Type* ret_type_;

  public:
    Signature(LLVMState* ls, const llvm::Type* rt)
      : ls_(ls)
      , ret_type_(rt)
    {}

    Signature(LLVMState* ls, const char* rt)
      : ls_(ls)
      , ret_type_(ls->ptr_type(rt))
    {}

    std::vector<const llvm::Type*>& types() {
      return types_;
    }

    Signature& operator<<(const char* name) {
      types_.push_back(ls_->ptr_type(name));

      return *this;
    }

    Signature& operator<<(const llvm::Type* type) {
      types_.push_back(type);

      return *this;
    }

    llvm::FunctionType* type() {
      return llvm::FunctionType::get(ret_type_, types_, false);
    }

    operator llvm::FunctionType*() { return type(); }

    llvm::Function* function(const char* name) {
      return llvm::cast<llvm::Function>(ls_->module()->getOrInsertFunction(name, type()));
    }

    void setDoesNotCapture(const char* name, int which) {
      function(name)->setDoesNotCapture(which, true);
    }

    llvm::CallInst* call(const char* name, llvm::Value** start, int size,
                      const char* inst_name, llvm::BasicBlock* block) {
      return llvm::CallInst::Create(function(name), start, start+size, inst_name, block);
    }

    llvm::CallInst* call(const char* name, llvm::Value** start, int size,
                      const char* inst_name, llvm::IRBuilder<>& builder) {
      return builder.CreateCall(function(name), start, start+size, inst_name);
    }

    llvm::CallInst* call(const char* name, std::vector<llvm::Value*> args,
                      const char* inst_name, llvm::IRBuilder<>& builder) {
      return builder.CreateCall(function(name), args.begin(), args.end(), inst_name);
    }

  };

  class BackgroundCompileRequest {
    VMMethod* vmm_;
    TypedRoot<Object*> mm_;
    bool is_block_;

  public:
    BackgroundCompileRequest(STATE, VMMethod* vmm, Object* mm, bool is_block=false)
      : vmm_(vmm)
      , mm_(state)
      , is_block_(is_block)
    {
      mm_.set(mm);
    }

    VMMethod* vmmethod() {
      return vmm_;
    }

    MachineMethod* machine_method() {
      return try_as<MachineMethod>(mm_.get());
    }

    BlockEnvironment* block_env() {
      return try_as<BlockEnvironment>(mm_.get());
    }

    bool is_block() {
      return is_block_;
    }
  };

}

#endif

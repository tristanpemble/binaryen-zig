(module
 (type $0 (func (param i32) (result i32)))
 (type $1 (func))
 (type $2 (func (result i32)))
 (type $3 (func (param i32 i32) (result i32)))
 (import "env" "puts" (func $puts (param i32) (result i32)))
 (memory $0 2)
 (data "Hello, world\00")
 (table $0 1 1 funcref)
 (global $global$0 (mut i32) (i32.const 66128))
 (global $global$1 i32 (i32.const 66128))
 (global $global$2 i32 (i32.const 581))
 (export "memory" (memory $0))
 (export "__wasm_call_ctors" (func $__wasm_call_ctors))
 (export "__heap_base" (global $global$1))
 (export "__data_end" (global $global$2))
 (export "main" (func $main))
 (func $__wasm_call_ctors (; 1 ;) (type $1)
  (call $__wasm_init_memory)
 )
 (func $__wasm_init_memory (; 2 ;) (type $1)
  (memory.init 0
   (i32.const 568)
   (i32.const 0)
   (i32.const 14)
  )
 )
 (func $__original_main (; 3 ;) (type $2) (result i32)
  (drop
   (call $puts
    (i32.const 568)
   )
  )
  (i32.const 0)
 )
 (func $main (; 3 ;) (type $3) (param $0 i32) (param $1 i32) (result i32)
  (call $__original_main)
 )
 ;; custom section "producers", size 111
)

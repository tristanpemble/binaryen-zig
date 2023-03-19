;; NOTE: Assertions have been generated by update_lit_checks.py --all-items and should not be edited.
;; RUN: foreach %s %t wasm-opt --nominal --closed-world --type-refining -all -S -o - | filecheck %s

(module
  ;; A struct with three fields. The first will have no writes, the second one
  ;; write of the same type, and the last a write of a subtype, which will allow
  ;; us to specialize that one.
  ;; CHECK:      (type $struct (struct (field (mut anyref)) (field (mut (ref i31))) (field (mut (ref i31)))))
  (type $struct (struct_subtype (field (mut anyref)) (field (mut (ref i31))) (field (mut anyref)) data))

  ;; CHECK:      (type $ref|$struct|_=>_none (func (param (ref $struct))))

  ;; CHECK:      (func $work (type $ref|$struct|_=>_none) (param $struct (ref $struct))
  ;; CHECK-NEXT:  (struct.set $struct 1
  ;; CHECK-NEXT:   (local.get $struct)
  ;; CHECK-NEXT:   (i31.new
  ;; CHECK-NEXT:    (i32.const 0)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (struct.set $struct 2
  ;; CHECK-NEXT:   (local.get $struct)
  ;; CHECK-NEXT:   (i31.new
  ;; CHECK-NEXT:    (i32.const 0)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.get $struct 2
  ;; CHECK-NEXT:    (local.get $struct)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $work (param $struct (ref $struct))
    (struct.set $struct 1
      (local.get $struct)
      (i31.new (i32.const 0))
    )
    (struct.set $struct 2
      (local.get $struct)
      (i31.new (i32.const 0))
    )
    (drop
      ;; The type of this struct.get must be updated after the field's type
      ;; changes, or the validator will complain.
      (struct.get $struct 2
        (local.get $struct)
      )
    )
  )
)

(module
  ;; A struct with a nullable field and a write of a non-nullable value. We
  ;; must keep the type nullable, unlike in the previous module, due to the
  ;; default value being null.

  ;; CHECK:      (type $struct (struct (field (mut i31ref))))
  (type $struct (struct_subtype (field (mut anyref)) data))

  ;; CHECK:      (type $ref|$struct|_=>_none (func (param (ref $struct))))

  ;; CHECK:      (func $work (type $ref|$struct|_=>_none) (param $struct (ref $struct))
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.new_default $struct)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (struct.set $struct 0
  ;; CHECK-NEXT:   (local.get $struct)
  ;; CHECK-NEXT:   (i31.new
  ;; CHECK-NEXT:    (i32.const 0)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $work (param $struct (ref $struct))
    (drop
      (struct.new_default $struct)
    )
    (struct.set $struct 0
      (local.get $struct)
      (i31.new (i32.const 0))
    )
  )
)

(module
  ;; Multiple writes to a field, with a LUB that is not equal to any of them.
  ;; We can at least improve from structref to a ref of $struct here. Note also
  ;; that we do so in all three types, not just the parent to which we write
  ;; (the children have no writes, but must still be updated).

  ;; CHECK:      (type $struct (struct (field (mut (ref $struct)))))
  (type $struct (struct_subtype (field (mut structref)) data))

  ;; CHECK:      (type $ref|$struct|_ref|$child-A|_ref|$child-B|_=>_none (func (param (ref $struct) (ref $child-A) (ref $child-B))))

  ;; CHECK:      (type $child-A (struct_subtype (field (mut (ref $struct))) $struct))
  (type $child-A (struct_subtype (field (mut structref)) $struct))

  ;; CHECK:      (type $child-B (struct_subtype (field (mut (ref $struct))) $struct))
  (type $child-B (struct_subtype (field (mut structref)) $struct))

  ;; CHECK:      (func $work (type $ref|$struct|_ref|$child-A|_ref|$child-B|_=>_none) (param $struct (ref $struct)) (param $child-A (ref $child-A)) (param $child-B (ref $child-B))
  ;; CHECK-NEXT:  (struct.set $struct 0
  ;; CHECK-NEXT:   (local.get $struct)
  ;; CHECK-NEXT:   (local.get $child-A)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (struct.set $struct 0
  ;; CHECK-NEXT:   (local.get $struct)
  ;; CHECK-NEXT:   (local.get $child-B)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $work (param $struct (ref $struct)) (param $child-A (ref $child-A)) (param $child-B (ref $child-B))
    (struct.set $struct 0
      (local.get $struct)
      (local.get $child-A)
    )
    (struct.set $struct 0
      (local.get $struct)
      (local.get $child-B)
    )
  )
)

(module
  ;; As above, but all writes are of $child-A, which allows more optimization
  ;; up to that type.

  ;; CHECK:      (type $struct (struct (field (mut (ref $child-A)))))

  ;; CHECK:      (type $child-A (struct_subtype (field (mut (ref $child-A))) $struct))
  (type $child-A (struct_subtype (field (mut structref)) $struct))

  (type $struct (struct_subtype (field (mut structref)) data))

  ;; CHECK:      (type $ref|$struct|_ref|$child-A|_=>_none (func (param (ref $struct) (ref $child-A))))

  ;; CHECK:      (type $none_=>_none (func))

  ;; CHECK:      (type $child-B (struct_subtype (field (mut (ref $child-A))) $struct))
  (type $child-B (struct_subtype (field (mut structref)) $struct))

  ;; CHECK:      (func $work (type $ref|$struct|_ref|$child-A|_=>_none) (param $struct (ref $struct)) (param $child-A (ref $child-A))
  ;; CHECK-NEXT:  (struct.set $struct 0
  ;; CHECK-NEXT:   (local.get $struct)
  ;; CHECK-NEXT:   (local.get $child-A)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (struct.set $struct 0
  ;; CHECK-NEXT:   (local.get $struct)
  ;; CHECK-NEXT:   (local.get $child-A)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $work (param $struct (ref $struct)) (param $child-A (ref $child-A))
    (struct.set $struct 0
      (local.get $struct)
      (local.get $child-A)
    )
    (struct.set $struct 0
      (local.get $struct)
      (local.get $child-A)
    )
  )

  ;; CHECK:      (func $keepalive (type $none_=>_none)
  ;; CHECK-NEXT:  (local $temp (ref null $child-B))
  ;; CHECK-NEXT:  (nop)
  ;; CHECK-NEXT: )
  (func $keepalive
   ;; Add a reference to $child-B just to keep it alive in the output for easier
   ;; comparisons to the previous testcase. Note that $child-B's field will be
   ;; refined, because its parent $struct forces it to be.
   (local $temp (ref null $child-B))
  )
)

(module
  ;; Write to the parent a child, and to the child a parent. The write to the
  ;; child prevents specialization even in the parent and we only improve up to
  ;; $struct but not to $child.

  ;; CHECK:      (type $struct (struct (field (mut (ref $struct)))))
  (type $struct (struct_subtype (field (mut structref)) data))

  ;; CHECK:      (type $child (struct_subtype (field (mut (ref $struct))) $struct))
  (type $child (struct_subtype (field (mut structref)) $struct))

  ;; CHECK:      (type $ref|$struct|_ref|$child|_=>_none (func (param (ref $struct) (ref $child))))

  ;; CHECK:      (func $work (type $ref|$struct|_ref|$child|_=>_none) (param $struct (ref $struct)) (param $child (ref $child))
  ;; CHECK-NEXT:  (struct.set $struct 0
  ;; CHECK-NEXT:   (local.get $struct)
  ;; CHECK-NEXT:   (local.get $child)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (struct.set $child 0
  ;; CHECK-NEXT:   (local.get $child)
  ;; CHECK-NEXT:   (local.get $struct)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $work (param $struct (ref $struct)) (param $child (ref $child))
    (struct.set $struct 0
      (local.get $struct)
      (local.get $child)
    )
    (struct.set $child 0
      (local.get $child)
      (local.get $struct)
    )
  )
)

(module
  ;; As above, but both writes are of $child, so we can optimize.

  ;; CHECK:      (type $struct (struct (field (mut (ref $child)))))

  ;; CHECK:      (type $child (struct_subtype (field (mut (ref $child))) $struct))
  (type $child (struct_subtype (field (mut structref)) $struct))

  (type $struct (struct_subtype (field (mut structref)) data))

  ;; CHECK:      (type $ref|$struct|_ref|$child|_=>_none (func (param (ref $struct) (ref $child))))

  ;; CHECK:      (func $work (type $ref|$struct|_ref|$child|_=>_none) (param $struct (ref $struct)) (param $child (ref $child))
  ;; CHECK-NEXT:  (struct.set $struct 0
  ;; CHECK-NEXT:   (local.get $struct)
  ;; CHECK-NEXT:   (local.get $child)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (struct.set $child 0
  ;; CHECK-NEXT:   (local.get $child)
  ;; CHECK-NEXT:   (local.get $child)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $work (param $struct (ref $struct)) (param $child (ref $child))
    (struct.set $struct 0
      (local.get $struct)
      (local.get $child)
    )
    (struct.set $child 0
      (local.get $child)
      (local.get $child)
    )
  )
)

(module
  ;; As in 2 testcases ago, write to the parent a child, and to the child a
  ;; parent, but now the writes happen in struct.new. Even with that precise
  ;; info, however, we can't make the parent field more specific than the
  ;; child's.

  ;; CHECK:      (type $struct (struct (field (mut (ref $struct)))))
  (type $struct (struct_subtype (field (mut structref)) data))

  ;; CHECK:      (type $child (struct_subtype (field (mut (ref $struct))) $struct))
  (type $child (struct_subtype (field (mut structref)) $struct))

  ;; CHECK:      (type $ref|$struct|_ref|$child|_=>_none (func (param (ref $struct) (ref $child))))

  ;; CHECK:      (func $work (type $ref|$struct|_ref|$child|_=>_none) (param $struct (ref $struct)) (param $child (ref $child))
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.new $struct
  ;; CHECK-NEXT:    (local.get $child)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.new $child
  ;; CHECK-NEXT:    (local.get $struct)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $work (param $struct (ref $struct)) (param $child (ref $child))
    (drop
      (struct.new $struct
        (local.get $child)
      )
    )
    (drop
      (struct.new $child
        (local.get $struct)
      )
    )
  )
)

(module
  ;; Write a parent to the parent and a child to the child. We can specialize
  ;; each of them to contain their own type. This tests that we are aware that
  ;; a struct.new is of a precise type, which means that seeing a type written
  ;; to a parent does not limit specialization in a child.
  ;;
  ;; (Note that we can't do a similar test with struct.set, as that would
  ;; imply the fields are mutable, which limits optimization, see the next
  ;; testcase after this.)

  ;; CHECK:      (type $struct (struct (field (ref $struct))))
  (type $struct (struct_subtype (field structref) data))

  ;; CHECK:      (type $child (struct_subtype (field (ref $child)) $struct))
  (type $child (struct_subtype (field structref) $struct))

  ;; CHECK:      (type $ref|$struct|_ref|$child|_=>_none (func (param (ref $struct) (ref $child))))

  ;; CHECK:      (func $work (type $ref|$struct|_ref|$child|_=>_none) (param $struct (ref $struct)) (param $child (ref $child))
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.new $struct
  ;; CHECK-NEXT:    (local.get $struct)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.new $child
  ;; CHECK-NEXT:    (local.get $child)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $work (param $struct (ref $struct)) (param $child (ref $child))
    (drop
      (struct.new $struct
        (local.get $struct)
      )
    )
    (drop
      (struct.new $child
        (local.get $child)
      )
    )
  )
)

(module
  ;; As above, but the fields are mutable. We cannot specialize them to
  ;; different types in this case, and both will become $struct (still an
  ;; improvement!)

  ;; CHECK:      (type $struct (struct (field (mut (ref $struct)))))
  (type $struct (struct_subtype (field (mut structref)) data))

  ;; CHECK:      (type $child (struct_subtype (field (mut (ref $struct))) $struct))
  (type $child (struct_subtype (field (mut structref)) $struct))

  ;; CHECK:      (type $ref|$struct|_ref|$child|_=>_none (func (param (ref $struct) (ref $child))))

  ;; CHECK:      (func $work (type $ref|$struct|_ref|$child|_=>_none) (param $struct (ref $struct)) (param $child (ref $child))
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.new $struct
  ;; CHECK-NEXT:    (local.get $struct)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.new $child
  ;; CHECK-NEXT:    (local.get $child)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $work (param $struct (ref $struct)) (param $child (ref $child))
    (drop
      (struct.new $struct
        (local.get $struct)
      )
    )
    (drop
      (struct.new $child
        (local.get $child)
      )
    )
  )
)

(module
  ;; As above, but the child also has a new field that is not in the parent. In
  ;; that case there is nothing stopping us from specializing that new field
  ;; to $child.

  ;; CHECK:      (type $struct (struct (field (mut (ref $struct)))))
  (type $struct (struct_subtype (field (mut structref)) data))

  ;; CHECK:      (type $child (struct_subtype (field (mut (ref $struct))) (field (mut (ref $child))) $struct))
  (type $child (struct_subtype (field (mut structref)) (field (mut structref)) $struct))

  ;; CHECK:      (type $ref|$struct|_ref|$child|_=>_none (func (param (ref $struct) (ref $child))))

  ;; CHECK:      (func $work (type $ref|$struct|_ref|$child|_=>_none) (param $struct (ref $struct)) (param $child (ref $child))
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.new $struct
  ;; CHECK-NEXT:    (local.get $struct)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.new $child
  ;; CHECK-NEXT:    (local.get $child)
  ;; CHECK-NEXT:    (local.get $child)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $work (param $struct (ref $struct)) (param $child (ref $child))
    (drop
      (struct.new $struct
        (local.get $struct)
      )
    )
    (drop
      (struct.new $child
        (local.get $child)
        (local.get $child)
      )
    )
  )
)

(module
  ;; A copy of a field does not prevent optimization (even though it assigns
  ;; the old type).

  ;; CHECK:      (type $struct (struct (field (mut (ref $struct)))))
  (type $struct (struct_subtype (field (mut structref)) data))

  ;; CHECK:      (type $ref|$struct|_=>_none (func (param (ref $struct))))

  ;; CHECK:      (func $work (type $ref|$struct|_=>_none) (param $struct (ref $struct))
  ;; CHECK-NEXT:  (struct.set $struct 0
  ;; CHECK-NEXT:   (local.get $struct)
  ;; CHECK-NEXT:   (local.get $struct)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (struct.set $struct 0
  ;; CHECK-NEXT:   (local.get $struct)
  ;; CHECK-NEXT:   (struct.get $struct 0
  ;; CHECK-NEXT:    (local.get $struct)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $work (param $struct (ref $struct))
    (struct.set $struct 0
      (local.get $struct)
      (local.get $struct)
    )
    (struct.set $struct 0
      (local.get $struct)
      (struct.get $struct 0
        (local.get $struct)
      )
    )
  )
)

(module
  ;; CHECK:      (type $X (struct ))

  ;; CHECK:      (type $Y (struct_subtype  $X))
  (type $Y (struct_subtype $X))

  ;; CHECK:      (type $none_=>_none (func))

  ;; CHECK:      (type $A (struct (field (ref $Y))))

  ;; CHECK:      (type $C (struct_subtype (field (ref $Y)) $A))
  (type $C (struct_subtype (field (ref $X)) $A))

  ;; CHECK:      (type $B (struct_subtype (field (ref $Y)) $A))
  (type $B (struct_subtype (field (ref $X)) $A))

  (type $A (struct_subtype (field (ref $X)) data))

  (type $X (struct))

  ;; CHECK:      (func $foo (type $none_=>_none)
  ;; CHECK-NEXT:  (local $unused (ref null $C))
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.new $B
  ;; CHECK-NEXT:    (struct.new_default $Y)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $foo
    ;; A use of type $C without ever creating an instance of it. We do still need
    ;; to update the type if we update the parent type, and we will in fact update
    ;; the parent $A's field from $X to $Y (see below), so we must do the same in
    ;; $C. As a result, all the fields with $X in them in all of $A, $B, $C will
    ;; be improved to contain $Y.
    (local $unused (ref null $C))

    (drop
      (struct.new $B
        (struct.new $Y) ;; This value is more specific than the field, which is an
                        ;; opportunity to subtype, which we do for $B. As $A, our
                        ;; parent, has no writes at all, we can propagate this
                        ;; info to there as well, which means we can perform the
                        ;; same optimization in $A as well.
      )
    )
  )
)

(module
  ;; As above, but remove the struct.new to $B, which means $A, $B, $C all have
  ;; no writes to them. There are no optimizations to do here.

  ;; CHECK:      (type $X (struct ))
  (type $X (struct))

  ;; CHECK:      (type $none_=>_none (func))

  ;; CHECK:      (type $A (struct (field (ref $X))))

  ;; CHECK:      (type $C (struct_subtype (field (ref $X)) $A))
  (type $C (struct_subtype (field (ref $X)) $A))

  ;; CHECK:      (type $B (struct_subtype (field (ref $X)) $A))
  (type $B (struct_subtype (field (ref $X)) $A))

  ;; CHECK:      (type $Y (struct_subtype  $X))
  (type $Y (struct_subtype $X))

  (type $A (struct_subtype (field (ref $X)) data))

  ;; CHECK:      (func $foo (type $none_=>_none)
  ;; CHECK-NEXT:  (local $unused1 (ref null $C))
  ;; CHECK-NEXT:  (local $unused2 (ref null $B))
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.new_default $Y)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $foo
    (local $unused1 (ref null $C))
    (local $unused2 (ref null $B))
    (drop (struct.new $Y))
  )
)

(module
  ;; CHECK:      (type $X (struct ))
  (type $X (struct))
  ;; CHECK:      (type $none_=>_none (func))

  ;; CHECK:      (type $A (struct (field (ref $X))))

  ;; CHECK:      (type $B (struct_subtype (field (ref $Y)) $A))
  (type $B (struct_subtype (field (ref $Y)) $A))

  (type $A (struct_subtype (field (ref $X)) data))

  ;; CHECK:      (type $Y (struct_subtype  $X))
  (type $Y (struct_subtype $X))

  ;; CHECK:      (func $foo (type $none_=>_none)
  ;; CHECK-NEXT:  (local $unused2 (ref null $B))
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.new $A
  ;; CHECK-NEXT:    (struct.new_default $X)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $foo
    ;; $B begins with its field of type $Y, which is more specific than the
    ;; field is in the supertype $A. There are no writes to $B, and so we end
    ;; up looking in the parent to see what to do; we should still emit a
    ;; reasonable type for $B, and there is no reason to make it *less*
    ;; specific, so leave things as they are.
    (local $unused2 (ref null $B))
    (drop
      (struct.new $A
        (struct.new $X)
      )
    )
  )
)

(module
  ;; CHECK:      (type $struct (struct (field (mut (ref null $struct)))))
  (type $struct (struct_subtype (field (mut (ref null struct))) data))

  ;; CHECK:      (type $ref|$struct|_=>_none (func (param (ref $struct))))

  ;; CHECK:      (func $update-null (type $ref|$struct|_=>_none) (param $struct (ref $struct))
  ;; CHECK-NEXT:  (struct.set $struct 0
  ;; CHECK-NEXT:   (local.get $struct)
  ;; CHECK-NEXT:   (local.get $struct)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (struct.set $struct 0
  ;; CHECK-NEXT:   (local.get $struct)
  ;; CHECK-NEXT:   (ref.null none)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $update-null (param $struct (ref $struct))
    (struct.set $struct 0
      (local.get $struct)
      ;; Write a $struct to the field.
      (local.get $struct)
    )
    (struct.set $struct 0
      (local.get $struct)
      ;; This null does not prevent refinement.
      (ref.null none)
    )
  )
)

(module
  ;; As above, but now the null is in a child. The result should be the same:
  ;; refine the field to nullable $struct.

  ;; CHECK:      (type $struct (struct (field (mut (ref null $struct)))))
  (type $struct (struct_subtype (field (mut (ref null struct))) data))
  ;; CHECK:      (type $child (struct_subtype (field (mut (ref null $struct))) $struct))
  (type $child (struct_subtype (field (mut (ref null struct))) $struct))

  ;; CHECK:      (type $ref|$struct|_ref|$child|_=>_none (func (param (ref $struct) (ref $child))))

  ;; CHECK:      (func $update-null (type $ref|$struct|_ref|$child|_=>_none) (param $struct (ref $struct)) (param $child (ref $child))
  ;; CHECK-NEXT:  (struct.set $struct 0
  ;; CHECK-NEXT:   (local.get $struct)
  ;; CHECK-NEXT:   (local.get $struct)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (struct.set $child 0
  ;; CHECK-NEXT:   (local.get $child)
  ;; CHECK-NEXT:   (ref.null none)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $update-null (param $struct (ref $struct)) (param $child (ref $child))
    (struct.set $struct 0
      (local.get $struct)
      (local.get $struct)
    )
    (struct.set $child 0
      (local.get $child)
      (ref.null none)
    )
  )
)

(module
  ;; As above, but now the null is in a parent. The result should be the same.

  ;; CHECK:      (type $struct (struct (field (mut (ref null $struct)))))
  (type $struct (struct_subtype (field (mut (ref null struct))) data))
  ;; CHECK:      (type $child (struct_subtype (field (mut (ref null $struct))) $struct))
  (type $child (struct_subtype (field (mut (ref null struct))) $struct))

  ;; CHECK:      (type $ref|$struct|_ref|$child|_=>_none (func (param (ref $struct) (ref $child))))

  ;; CHECK:      (func $update-null (type $ref|$struct|_ref|$child|_=>_none) (param $struct (ref $struct)) (param $child (ref $child))
  ;; CHECK-NEXT:  (struct.set $struct 0
  ;; CHECK-NEXT:   (local.get $struct)
  ;; CHECK-NEXT:   (ref.null none)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (struct.set $child 0
  ;; CHECK-NEXT:   (local.get $child)
  ;; CHECK-NEXT:   (local.get $struct)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $update-null (param $struct (ref $struct)) (param $child (ref $child))
    (struct.set $struct 0
      (local.get $struct)
      (ref.null none)
    )
    (struct.set $child 0
      (local.get $child)
      (local.get $struct)
    )
  )
)

(module
  ;; CHECK:      (type $struct (struct (field (mut nullref))))
  (type $struct (struct_subtype (field (mut (ref null struct))) data))

  ;; CHECK:      (type $ref|$struct|_=>_none (func (param (ref $struct))))

  ;; CHECK:      (func $work (type $ref|$struct|_=>_none) (param $struct (ref $struct))
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.new_default $struct)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $work (param $struct (ref $struct))
    ;; The only write to this struct is of a null default value, so we can
    ;; optimize to nullref.
    (drop
      (struct.new_default $struct)
    )
  )
)

(module
  ;; CHECK:      (type $struct (struct (field (mut (ref null $struct)))))
  (type $struct (struct_subtype (field (mut (ref null struct))) data))

  ;; CHECK:      (type $ref|$struct|_=>_none (func (param (ref $struct))))

  ;; CHECK:      (func $work (type $ref|$struct|_=>_none) (param $struct (ref $struct))
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.new_default $struct)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (struct.set $struct 0
  ;; CHECK-NEXT:   (local.get $struct)
  ;; CHECK-NEXT:   (local.get $struct)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $work (param $struct (ref $struct))
    (drop
      (struct.new_default $struct)
    )
    ;; Also write a $struct. The null default should not prevent us from
    ;; refining the field's type to $struct (but nullable).
    (struct.set $struct 0
      (local.get $struct)
      (local.get $struct)
    )
  )
)

(module
  ;; CHECK:      (type $struct (struct (field (mut (ref null $struct)))))
  (type $struct (struct_subtype (field (mut (ref null struct))) data))

  ;; CHECK:      (type $ref|$struct|_=>_none (func (param (ref $struct))))

  ;; CHECK:      (func $work (type $ref|$struct|_=>_none) (param $struct (ref $struct))
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.new $struct
  ;; CHECK-NEXT:    (ref.null none)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (struct.set $struct 0
  ;; CHECK-NEXT:   (local.get $struct)
  ;; CHECK-NEXT:   (local.get $struct)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $work (param $struct (ref $struct))
    ;; As before, but instead of new_default, new, and use a null in the given
    ;; value.
    (drop
      (struct.new $struct
        (ref.null none)
      )
    )
    (struct.set $struct 0
      (local.get $struct)
      (local.get $struct)
    )
  )
)

(module
  ;; CHECK:      (type $struct (struct (field (mut (ref null $child))) (field (mut (ref null $struct)))))
  (type $struct (struct_subtype (field (mut (ref null struct))) (field (mut (ref null struct))) data))

  ;; CHECK:      (type $child (struct_subtype (field (mut (ref null $child))) (field (mut (ref null $struct))) $struct))
  (type $child (struct_subtype (field (mut (ref null struct))) (field (mut (ref null struct))) $struct))

  ;; CHECK:      (type $ref|$struct|_ref|$child|_=>_none (func (param (ref $struct) (ref $child))))

  ;; CHECK:      (func $update-null (type $ref|$struct|_ref|$child|_=>_none) (param $struct (ref $struct)) (param $child (ref $child))
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.new $struct
  ;; CHECK-NEXT:    (local.get $child)
  ;; CHECK-NEXT:    (ref.null none)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.new $struct
  ;; CHECK-NEXT:    (ref.null none)
  ;; CHECK-NEXT:    (local.get $struct)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $update-null (param $struct (ref $struct)) (param $child (ref $child))
    ;; Update nulls in two fields that are separately optimized to separate
    ;; values.
    (drop
      (struct.new $struct
        (local.get $child)
        (ref.null none)
      )
    )
    (drop
      (struct.new $struct
        (ref.null none)
        (local.get $struct)
      )
    )
  )
)

(module
  ;; There are two parallel type hierarchies here: "Outer", which are objects
  ;; that have fields, that contain the "Inner" objects.
  ;;
  ;; Root-Outer -> Leaf1-Outer
  ;;            -> Leaf2-Outer
  ;;
  ;; Root-Inner -> Leaf1-Inner
  ;;            -> Leaf2-Inner
  ;;
  ;; Adding their contents, where X[Y] means X has a field of type Y:
  ;;
  ;; Root-Outer[Root-Inner] -> Leaf1-Outer[Leaf1-Inner]
  ;;                        -> Leaf2-Outer[Leaf2-Inner]

  ;; CHECK:      (type $Root-Inner (struct ))

  ;; CHECK:      (type $Leaf2-Inner (struct_subtype  $Root-Inner))
  (type $Leaf2-Inner (struct_subtype  $Root-Inner))

  ;; CHECK:      (type $ref?|$Leaf1-Outer|_=>_none (func (param (ref null $Leaf1-Outer))))

  ;; CHECK:      (type $Root-Outer (struct (field (ref $Leaf2-Inner))))

  ;; CHECK:      (type $Leaf2-Outer (struct_subtype (field (ref $Leaf2-Inner)) $Root-Outer))

  ;; CHECK:      (type $Leaf1-Outer (struct_subtype (field (ref $Leaf2-Inner)) $Root-Outer))
  (type $Leaf1-Outer (struct_subtype (field (ref $Leaf1-Inner)) $Root-Outer))

 (type $Leaf2-Outer (struct_subtype (field (ref $Leaf2-Inner)) $Root-Outer))

  (type $Root-Outer (struct_subtype (field (ref $Root-Inner)) data))

  (type $Root-Inner (struct))

  (type $Leaf1-Inner (struct_subtype (field i32) $Root-Inner))

  ;; CHECK:      (func $func (type $ref?|$Leaf1-Outer|_=>_none) (param $Leaf1-Outer (ref null $Leaf1-Outer))
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (block ;; (replaces something unreachable we can't emit)
  ;; CHECK-NEXT:    (drop
  ;; CHECK-NEXT:     (block
  ;; CHECK-NEXT:      (drop
  ;; CHECK-NEXT:       (local.get $Leaf1-Outer)
  ;; CHECK-NEXT:      )
  ;; CHECK-NEXT:      (unreachable)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (unreachable)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.new $Leaf2-Outer
  ;; CHECK-NEXT:    (struct.new_default $Leaf2-Inner)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $func (param $Leaf1-Outer (ref null $Leaf1-Outer))
    (drop
      ;; The situation here is that we have only a get for some types, and no
      ;; other constraints. As we ignore gets, we work under no constraints at
      ;; We then have to pick some type, so we pick the one used by our
      ;; supertype - and the supertype might have picked up a type from another
      ;; branch of the type tree, which is not a subtype of ours.
      ;;
      ;; In more detail, we never create an instance of $Leaf1-Outer, and we
      ;; only have a get of its field. This optimization ignores the get (to not
      ;; be limited by it). It will then optimize $Leaf1-Outer's field of
      ;; $Leaf1-Inner (another struct for which we have no creation, and only a
      ;; get) into $Leaf2-Inner, which is driven by the fact that we do have a
      ;; creation of $Leaf2-Inner. But then this struct.get $Leaf1-Inner on field
      ;; 0 is no longer valid, as we turn $Leaf1-Inner => $Leaf2-Inner, and
      ;; $Leaf2-Inner has no field 0. To keep the module validating, we must not
      ;; emit that. Instead, since there can be no instance of $Leaf1-Inner (as
      ;; mentioned before, it is never created, nor anything that can be cast to
      ;; it), we know this code is logically unreachable, and can emit an
      ;; unreachable here.
      (struct.get $Leaf1-Inner 0
        (struct.get $Leaf1-Outer 0
          (local.get $Leaf1-Outer)
        )
      )
    )
    (drop
      (struct.new $Leaf2-Outer
        (struct.new_default $Leaf2-Inner)
      )
    )
  )
)

(module
  ;; CHECK:      (type $A (struct (field (mut (ref null $A)))))
  (type $A (struct_subtype (field (mut (ref null $A))) data))

  ;; CHECK:      (type $ref|$A|_ref?|$A|_=>_none (func (param (ref $A) (ref null $A))))

  ;; CHECK:      (func $non-nullability (type $ref|$A|_ref?|$A|_=>_none) (param $nn (ref $A)) (param $A (ref null $A))
  ;; CHECK-NEXT:  (local $temp (ref null $A))
  ;; CHECK-NEXT:  (struct.set $A 0
  ;; CHECK-NEXT:   (local.get $A)
  ;; CHECK-NEXT:   (local.get $nn)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (struct.set $A 0
  ;; CHECK-NEXT:   (local.get $A)
  ;; CHECK-NEXT:   (local.tee $temp
  ;; CHECK-NEXT:    (struct.get $A 0
  ;; CHECK-NEXT:     (local.get $A)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.new $A
  ;; CHECK-NEXT:    (local.tee $temp
  ;; CHECK-NEXT:     (struct.get $A 0
  ;; CHECK-NEXT:      (local.get $A)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $non-nullability (param $nn (ref $A)) (param $A (ref null $A))
    (local $temp (ref null $A))
    ;; Set a non-null value to the field.
    (struct.set $A 0
      (local.get $A)
      (local.get $nn)
    )
    ;; Set a get of the same field to the field - this is a copy. However, the
    ;; copy goes through a local.tee. Even after we refine the type of the field
    ;; to non-nullable, the tee will remain nullable since it has the type of
    ;; the local. We could add casts perhaps, but for now we do not optimize,
    ;; and type $A's field will remain nullable.
    (struct.set $A 0
      (local.get $A)
      (local.tee $temp
        (struct.get $A 0
          (local.get $A)
        )
      )
    )
    ;; The same, but with a struct.new.
    (drop
      (struct.new $A
        (local.tee $temp
          (struct.get $A 0
            (local.get $A)
          )
        )
      )
    )
  )
)

(module
  ;; CHECK:      (type $A (struct (field (ref null $A))))
  (type $A (struct_subtype (field (ref null $A)) data))
  ;; CHECK:      (type $B (struct_subtype (field (ref null $B)) $A))
  (type $B (struct_subtype (field (ref null $A)) $A))

  ;; CHECK:      (type $ref?|$B|_ref?|$A|_=>_none (func (param (ref null $B) (ref null $A))))

  ;; CHECK:      (func $heap-type (type $ref?|$B|_ref?|$A|_=>_none) (param $b (ref null $B)) (param $A (ref null $A))
  ;; CHECK-NEXT:  (local $a (ref null $A))
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.new $B
  ;; CHECK-NEXT:    (local.get $b)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.new $A
  ;; CHECK-NEXT:    (local.tee $a
  ;; CHECK-NEXT:     (struct.get $A 0
  ;; CHECK-NEXT:      (local.get $A)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $heap-type (param $b (ref null $B)) (param $A (ref null $A))
    (local $a (ref null $A))
    ;; Similar to the above, but instead of non-nullability being the issue,
    ;; now it is the heap type. We write a B to B's field, so we can trivially
    ;; refine that, and we want to do a similar refinement to the supertype A.
    ;; But below we do a copy on A through a tee. As above, the tee's type will
    ;; not change, so we do not optimize type $A's field (however, we can
    ;; refine $B's field, which is safe to do).
    (drop
      (struct.new $B
        (local.get $b)
      )
    )
    (drop
      (struct.new $A
        (local.tee $a
          (struct.get $A 0
            (local.get $A)
          )
        )
      )
    )
  )
)

(module
  ;; CHECK:      (type $A (struct (field (mut (ref $A)))))
  (type $A (struct_subtype (field (mut (ref null $A))) data))

  ;; CHECK:      (type $ref|$A|_ref?|$A|_=>_none (func (param (ref $A) (ref null $A))))

  ;; CHECK:      (func $non-nullability-block (type $ref|$A|_ref?|$A|_=>_none) (param $nn (ref $A)) (param $A (ref null $A))
  ;; CHECK-NEXT:  (struct.set $A 0
  ;; CHECK-NEXT:   (local.get $A)
  ;; CHECK-NEXT:   (local.get $nn)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (struct.set $A 0
  ;; CHECK-NEXT:   (local.get $A)
  ;; CHECK-NEXT:   (if (result (ref $A))
  ;; CHECK-NEXT:    (i32.const 1)
  ;; CHECK-NEXT:    (struct.get $A 0
  ;; CHECK-NEXT:     (local.get $A)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (unreachable)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.new $A
  ;; CHECK-NEXT:    (if (result (ref $A))
  ;; CHECK-NEXT:     (i32.const 1)
  ;; CHECK-NEXT:     (struct.get $A 0
  ;; CHECK-NEXT:      (local.get $A)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:     (unreachable)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $non-nullability-block (param $nn (ref $A)) (param $A (ref null $A))
    (struct.set $A 0
      (local.get $A)
      (local.get $nn)
    )
    ;; As above, but instead of a local.tee fallthrough, use an if. We *can*
    ;; optimize in this case, as ifs etc do not pose a problem (we'll refinalize
    ;; the ifs to the proper, non-nullable type, the same as the field).
    (struct.set $A 0
      (local.get $A)
      (if (result (ref null $A))
        (i32.const 1)
        (struct.get $A 0
          (local.get $A)
        )
        (unreachable)
      )
    )
    (drop
      (struct.new $A
        (if (result (ref null $A))
          (i32.const 1)
          (struct.get $A 0
            (local.get $A)
          )
          (unreachable)
        )
      )
    )
  )
)

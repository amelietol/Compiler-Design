open Ll
open Llutil
open Ast

(* instruction streams ------------------------------------------------------ *)

(* As in the last project, we'll be working with a flattened representation
   of LLVMlite programs to make emitting code easier. This version
   additionally makes it possible to emit elements will be gathered up and
   "hoisted" to specific parts of the constructed CFG
   - G of gid * Ll.gdecl: allows you to output global definitions in the middle
     of the instruction stream. You will find this useful for compiling string
     literals
   - E of uid * insn: allows you to emit an instruction that will be moved up
     to the entry block of the current function. This will be useful for 
     compiling local variable declarations
*)

type elt = 
  | L of Ll.lbl             (* block labels *)
  | I of uid * Ll.insn      (* instruction *)
  | T of Ll.terminator      (* block terminators *)
  | G of gid * Ll.gdecl     (* hoisted globals (usually strings) *)
  | E of uid * Ll.insn      (* hoisted entry block instructions *)

type stream = elt list
let ( >@ ) x y = y @ x
let ( >:: ) x y = y :: x
let lift : (uid * insn) list -> stream = List.rev_map (fun (x,i) -> I (x,i))

(* Build a CFG and collection of global variable definitions from a stream *)
let cfg_of_stream (code:stream) : Ll.cfg * (Ll.gid * Ll.gdecl) list  =
    let gs, einsns, insns, term_opt, blks = List.fold_left
      (fun (gs, einsns, insns, term_opt, blks) e ->
        match e with
        | L l ->
           begin match term_opt with
           | None -> 
              if (List.length insns) = 0 then (gs, einsns, [], None, blks)
              else failwith @@ Printf.sprintf "build_cfg: block labeled %s has\
                                               no terminator" l
           | Some term ->
              (gs, einsns, [], None, (l, {insns; term})::blks)
           end
        | T t  -> (gs, einsns, [], Some (Llutil.Parsing.gensym "tmn", t), blks)
        | I (uid,insn)  -> (gs, einsns, (uid,insn)::insns, term_opt, blks)
        | G (gid,gdecl) ->  ((gid,gdecl)::gs, einsns, insns, term_opt, blks)
        | E (uid,i) -> (gs, (uid, i)::einsns, insns, term_opt, blks)
      ) ([], [], [], None, []) code
    in
    match term_opt with
    | None -> failwith "build_cfg: entry block has no terminator" 
    | Some term -> 
       let insns = einsns @ insns in
       ({insns; term}, blks), gs


(* compilation contexts ----------------------------------------------------- *)

(* To compile OAT variables, we maintain a mapping of source identifiers to the
   corresponding LLVMlite operands. Bindings are added for global OAT variables
   and local variables that are in scope. *)

module Ctxt = struct

  type t = (Ast.id * (Ll.ty * Ll.operand)) list
  let empty = []

  (* Add a binding to the context *)
  let add (c:t) (id:id) (bnd:Ll.ty * Ll.operand) : t = (id,bnd)::c

  (* Lookup a binding in the context *)
  let lookup (id:Ast.id) (c:t) : Ll.ty * Ll.operand =
    List.assoc id c

  (* Lookup a function, fail otherwise *)
  let lookup_function (id:Ast.id) (c:t) : Ll.ty * Ll.operand =
    match List.assoc id c with
    | Ptr (Fun (args, ret)), g -> Ptr (Fun (args, ret)), g
    | _ -> failwith @@ id ^ " not bound to a function"

  let lookup_function_option (id:Ast.id) (c:t) : (Ll.ty * Ll.operand) option =
    try Some (lookup_function id c) with _ -> None
  
end

(* compiling OAT types ------------------------------------------------------ *)

(* The mapping of source types onto LLVMlite is straightforward. Booleans and ints
   are represented as the corresponding integer types. OAT strings are
   pointers to bytes (I8). Arrays are the most interesting type: they are
   represented as pointers to structs where the first component is the number
   of elements in the following array.

   The trickiest part of this project will be satisfying LLVM's rudimentary type
   system. Recall that global arrays in LLVMlite need to be declared with their
   length in the type to statically allocate the right amount of memory. The 
   global strings and arrays you emit will therefore have a more specific type
   annotation than the output of cmp_rty. You will have to carefully bitcast
   gids to satisfy the LLVM type checker.
*)

let rec cmp_ty : Ast.ty -> Ll.ty = function
  | Ast.TBool  -> I1
  | Ast.TInt   -> I64
  | Ast.TRef r -> Ptr (cmp_rty r)

and cmp_rty : Ast.rty -> Ll.ty = function
  | Ast.RString  -> I8
  | Ast.RArray u -> Struct [I64; Array(0, cmp_ty u)]
  | Ast.RFun (ts, t) -> 
      let args, ret = cmp_fty (ts, t) in
      Fun (args, ret)

and cmp_ret_ty : Ast.ret_ty -> Ll.ty = function
  | Ast.RetVoid  -> Void
  | Ast.RetVal t -> cmp_ty t

and cmp_fty (ts, r) : Ll.fty =
  List.map cmp_ty ts, cmp_ret_ty r


let typ_of_binop : Ast.binop -> Ast.ty * Ast.ty * Ast.ty = function
  | Add | Mul | Sub | Shl | Shr | Sar | IAnd | IOr -> (TInt, TInt, TInt)
  | Eq | Neq | Lt | Lte | Gt | Gte -> (TInt, TInt, TBool)
  | And | Or -> (TBool, TBool, TBool)

let typ_of_unop : Ast.unop -> Ast.ty * Ast.ty = function
  | Neg | Bitnot -> (TInt, TInt)
  | Lognot       -> (TBool, TBool)

(* Compiler Invariants

   The LLVM IR type of a variable (whether global or local) that stores an Oat
   array value (or any other reference type, like "string") will always be a
   double pointer.  In general, any Oat variable of Oat-type t will be
   represented by an LLVM IR value of type Ptr (cmp_ty t).  So the Oat variable
   x : int will be represented by an LLVM IR value of type i64*, y : string will
   be represented by a value of type i8**, and arr : int[] will be represented
   by a value of type {i64, [0 x i64]}**.  Whether the LLVM IR type is a
   "single" or "double" pointer depends on whether t is a reference type.

   We can think of the compiler as paying careful attention to whether a piece
   of Oat syntax denotes the "value" of an expression or a pointer to the
   "storage space associated with it".  This is the distinction between an
   "expression" and the "left-hand-side" of an assignment statement.  Compiling
   an Oat variable identifier as an expression ("value") does the load, so
   cmp_exp called on an Oat variable of type t returns (code that) generates a
   LLVM IR value of type cmp_ty t.  Compiling an identifier as a left-hand-side
   does not do the load, so cmp_lhs called on an Oat variable of type t returns
   and operand of type (cmp_ty t)*.  Extending these invariants to account for
   array accesses: the assignment e1[e2] = e3; treats e1[e2] as a
   left-hand-side, so we compile it as follows: compile e1 as an expression to
   obtain an array value (which is of pointer of type {i64, [0 x s]}* ).
   compile e2 as an expression to obtain an operand of type i64, generate code
   that uses getelementptr to compute the offset from the array value, which is
   a pointer to the "storage space associated with e1[e2]".

   On the other hand, compiling e1[e2] as an expression (to obtain the value of
   the array), we can simply compile e1[e2] as a left-hand-side and then do the
   load.  So cmp_exp and cmp_lhs are mutually recursive.  [[Actually, as I am
   writing this, I think it could make sense to factor the Oat grammar in this
   way, which would make things clearer, I may do that for next time around.]]

 
   Consider globals7.oat

   /--------------- globals7.oat ------------------ 
   global arr = int[] null;

   int foo() { 
     var x = new int[3]; 
     arr = x; 
     x[2] = 3; 
     return arr[2]; 
   }
   /------------------------------------------------

   The translation (given by cmp_ty) of the type int[] is {i64, [0 x i64}* so
   the corresponding LLVM IR declaration will look like:

   @arr = global { i64, [0 x i64] }* null

   This means that the type of the LLVM IR identifier @arr is {i64, [0 x i64]}**
   which is consistent with the type of a locally-declared array variable.

   The local variable x would be allocated and initialized by (something like)
   the following code snippet.  Here %_x7 is the LLVM IR uid containing the
   pointer to the "storage space" for the Oat variable x.

   %_x7 = alloca { i64, [0 x i64] }*                              ;; (1)
   %_raw_array5 = call i64*  @oat_alloc_array(i64 3)              ;; (2)
   %_array6 = bitcast i64* %_raw_array5 to { i64, [0 x i64] }*    ;; (3)
   store { i64, [0 x i64]}* %_array6, { i64, [0 x i64] }** %_x7   ;; (4)

   (1) note that alloca uses cmp_ty (int[]) to find the type, so %_x7 has 
       the same type as @arr 

   (2) @oat_alloc_array allocates len+1 i64's 

   (3) we have to bitcast the result of @oat_alloc_array so we can store it
        in %_x7 

   (4) stores the resulting array value (itself a pointer) into %_x7 

  The assignment arr = x; gets compiled to (something like):

  %_x8 = load { i64, [0 x i64] }*, { i64, [0 x i64] }** %_x7     ;; (5)
  store {i64, [0 x i64] }* %_x8, { i64, [0 x i64] }** @arr       ;; (6)

  (5) load the array value (a pointer) that is stored in the address pointed 
      to by %_x7 

  (6) store the array value (a pointer) into @arr 

  The assignment x[2] = 3; gets compiled to (something like):

  %_x9 = load { i64, [0 x i64] }*, { i64, [0 x i64] }** %_x7      ;; (7)
  %_index_ptr11 = getelementptr { i64, [0 x  i64] }, 
                  { i64, [0 x i64] }* %_x9, i32 0, i32 1, i32 2   ;; (8)
  store i64 3, i64* %_index_ptr11                                 ;; (9)

  (7) as above, load the array value that is stored %_x7 

  (8) calculate the offset from the array using GEP

  (9) store 3 into the array

  Finally, return arr[2]; gets compiled to (something like) the following.
  Note that the way arr is treated is identical to x.  (Once we set up the
  translation, there is no difference between Oat globals and locals, except
  how their storage space is initially allocated.)

  %_arr12 = load { i64, [0 x i64] }*, { i64, [0 x i64] }** @arr    ;; (10)
  %_index_ptr14 = getelementptr { i64, [0 x i64] },                
                 { i64, [0 x i64] }* %_arr12, i32 0, i32 1, i32 2  ;; (11)
  %_index15 = load i64, i64* %_index_ptr14                         ;; (12)
  ret i64 %_index15

  (10) just like for %_x9, load the array value that is stored in @arr 

  (11)  calculate the array index offset

  (12) load the array value at the index 

*)

(* Global initialized arrays:

  There is another wrinkle: To compile global initialized arrays like in the
  globals4.oat, it is helpful to do a bitcast once at the global scope to
  convert the "precise type" required by the LLVM initializer to the actual
  translation type (which sets the array length to 0).  So for globals4.oat,
  the arr global would compile to (something like):

  @arr = global { i64, [0 x i64] }* bitcast 
           ({ i64, [4 x i64] }* @_global_arr5 to { i64, [0 x i64] }* ) 
  @_global_arr5 = global { i64, [4 x i64] } 
                  { i64 4, [4 x i64] [ i64 1, i64 2, i64 3, i64 4 ] }

*) 



(* Some useful helper functions *)

(* Generate a fresh temporary identifier. Since OAT identifiers cannot begin
   with an underscore, these should not clash with any source variables *)
let gensym : string -> string =
  let c = ref 0 in
  fun (s:string) -> incr c; Printf.sprintf "_%s%d" s (!c)

(* Amount of space an Oat type takes when stored in the satck, in bytes.  
   Note that since structured values are manipulated by reference, all
   Oat values take 8 bytes on the stack.
*)
let size_oat_ty (t : Ast.ty) = 8L

(* Generate code to allocate a zero-initialized array of source type TRef (RArray t) of the
   given size. Note "size" is an operand whose value can be computed at
   runtime *)
let oat_alloc_array (t:Ast.ty) (size:Ll.operand) : Ll.ty * operand * stream =
  let ans_id, arr_id = gensym "array", gensym "raw_array" in
  let ans_ty = cmp_ty @@ TRef (RArray t) in
  let arr_ty = Ptr I64 in
  ans_ty, Id ans_id, lift
    [ arr_id, Call(arr_ty, Gid "oat_alloc_array", [I64, size])
    ; ans_id, Bitcast(arr_ty, Id arr_id, ans_ty) ]

(* Compiles an expression exp in context c, outputting the Ll operand that will
   recieve the value of the expression, and the stream of instructions
   implementing the expression. 

   Tips:
   - use the provided cmp_ty function!

   - string literals (CStr s) should be hoisted. You'll need to make sure
     either that the resulting gid has type (Ptr I8), or, if the gid has type
     [n x i8] (where n is the length of the string), convert the gid to a 
     (Ptr I8), e.g., by using getelementptr.

   - use the provided "oat_alloc_array" function to implement literal arrays
     (CArr) and the (NewArr) expressions

*)

let rec cmp_exp (c:Ctxt.t) (exp:Ast.exp node) : Ll.ty * Ll.operand * stream =
  match exp.elt with
  | CInt i -> (I64, Const i, [])
  | CBool b -> (I1, Const (if b then 1L else 0L), [])
  | CNull r -> (cmp_ty (TRef r), Null, [])
  | Bop (b, e1, e2) -> 
    let t1, op1, s1 = cmp_exp c e1 in
    let t2, op2, s2 = cmp_exp c e2 in
    let _, _, t = typ_of_binop b in
    let ll_instr = match b with
      | Ast.Add -> Binop(Add, t1, op1, op2)
      | Ast.Sub -> Binop(Sub, t1, op1, op2)
      | Ast.Mul -> Binop(Mul, t1, op1, op2)
      | Ast.Shl -> Binop(Shl, t1, op1, op2)
      | Ast.Shr -> Binop(Lshr, t1, op1, op2)
      | Ast.Sar -> Binop(Ashr, t1, op1, op2)
      | Ast.And -> Binop(And, t1, op1, op2)
      | Ast.Or -> Binop(Or, t1, op1, op2)
      | Ast.IAnd -> Binop(And, t1, op1, op2)
      | Ast.IOr -> Binop(Or, t1, op1, op2)

      | Ast.Lt -> Icmp (Slt, t1, op1, op2) 
      | Ast.Lte -> Icmp (Sle, t1, op1, op2)
      | Ast.Gt -> Icmp (Sgt, t1, op1, op2)
      | Ast.Gte -> Icmp (Sge, t1, op1, op2)
      | Ast.Eq -> Icmp (Eq, t1, op1, op2)
      | Ast.Neq -> Icmp (Ne, t1, op1, op2)
      
    in
    let res_id = gensym "bop" in
    let insn_elt = I (res_id, ll_instr) in
    let full_stream = s1 >@ s2 >:: insn_elt in
    (cmp_ty t, Id res_id, full_stream)
  | Id id ->
    let ptr_ty, ptr_op = Ctxt.lookup id c in
    let res_id = gensym id in
    let actual_ty = match ptr_ty with
      | Ptr act_ty -> act_ty
      | _ -> failwith "Expected pointer type"
    in
    let insn = I (res_id, Load (ptr_ty, ptr_op)) in
    (actual_ty, Id res_id, [ insn ])
  | Uop (u, e) ->
    let t1, op1, s1 = cmp_exp c e in
    let _,  t = typ_of_unop u in
    let ll_instr = match u with
    | Ast.Neg -> Binop (Sub, I64, Const 0L, op1)
    | Ast.Lognot -> Binop (Xor, I1, op1, Const 1L)
    | Ast.Bitnot -> Binop (Xor, I64, op1, Const (-1L))
    in
    let res_id = gensym "uop" in
    let insn_elt = I (res_id, ll_instr) in
    let full_stream = s1 >:: insn_elt in
    (cmp_ty t, Id res_id, full_stream)
  | Call (fn_exp, args) ->
    let fname = match fn_exp.elt with
      | Id name -> name
      | _ -> failwith "fname expected"
    in
    let f_ty, f_op = Ctxt.lookup_function fname c in
    let ret_ty = match f_ty with
      | Ptr (Fun (_, r)) -> r
      | _ -> failwith "not a function"
    in
    let (args_ops, all_arg_streams) = List.fold_left (fun (ty_op, stream) arg ->
      let arg_ty, arg_op, arg_stream = cmp_exp c arg in
      (ty_op @ [(arg_ty, arg_op)], stream >@ arg_stream)
      ) ([], []) args
    in
    let res_id = gensym "call" in
    let insn = I (res_id, Call (ret_ty, f_op, args_ops)) in
    (ret_ty, Id res_id, all_arg_streams >:: insn)
  | CStr str ->
    let len = String.length str + 1 in
    let str_ty = Array (len, I8) in
    let str_id = gensym "str" in
    let g_elt = G (str_id, (str_ty, GString str)) in
    let res_id = gensym "str_ptr" in
    let insn = I (res_id, Gep (Ptr str_ty, Gid str_id, [Const 0L; Const 0L])) in
    (Ptr I8, Id res_id, [ g_elt; insn ])
  | NewArr (ty, e) ->
    let _, size_op, size_stream = cmp_exp c e in
    let arr_ty, arr_op, alloc_stream = oat_alloc_array ty size_op in
    (arr_ty, arr_op, size_stream >@ alloc_stream)
  | Index (e1, e2) ->
    let elem_ty, ptr_op, ptr_str = cmp_index_ptr c e1 e2 in
    let res_id = gensym "index" in
    let load_insn = I (res_id, Load (Ptr elem_ty, ptr_op)) in
    (elem_ty, Id res_id, ptr_str >:: load_insn)
  | CArr (ty, elts) ->
    let len = List.length elts in
    let arr_ty, arr_op, alloc_str = oat_alloc_array ty (Const (Int64.of_int len)) in
    let init_streams = List.mapi (fun i elt ->
      let val_ty, val_op, val_str = cmp_exp c elt in
      let ptr_id = gensym "slot" in
      let gep_insn = I (ptr_id, Gep (arr_ty, arr_op, [Const 0L; Const 1L; Const (Int64.of_int i)])) in
      let store_insn = I (gensym "store", Store (val_ty, val_op, Id ptr_id)) in
      val_str >:: gep_insn >:: store_insn
    ) elts in
    let full_stream = List.fold_left (>@) alloc_str init_streams in
    (arr_ty, arr_op, full_stream)
  | _ -> failwith "exp not yet implemented"

  and cmp_index_ptr (c:Ctxt.t) (arr_exp:Ast.exp node) (idx_exp:Ast.exp node) : Ll.ty * Ll.operand * stream =
  let arr_ty, arr_op, arr_str = cmp_exp c arr_exp in
  let _, idx_op, idx_str = cmp_exp c idx_exp in
  let elem_ty = match arr_ty with
    | Ptr (Struct [_; Array (_, t)]) -> t
    | _ -> failwith "expected array pointer"
  in
  let ptr_id = gensym "index_ptr" in
  let gep_insn = I (ptr_id, Gep (arr_ty, arr_op, [Const 0L; Const 1L; idx_op])) in
  (elem_ty, Id ptr_id, arr_str >@ idx_str >:: gep_insn)


(* Compile a statement in context c with return typ rt. Return a new context, 
   possibly extended with new local bindings, and the instruction stream
   implementing the statement.

   Left-hand-sides of assignment statements must either be OAT identifiers,
   or an index into some arbitrary expression of array type. Otherwise, the
   program is not well-formed and your compiler may throw an error.

   Tips:
   - for local variable declarations, you will need to emit Allocas in the
     entry block of the current function using the E() constructor.

   - don't forget to add a bindings to the context for local variable 
     declarations
   
   - you can avoid some work by translating For loops to the corresponding
     While loop, building the AST and recursively calling cmp_stmt

   - you might find it helpful to reuse the code you wrote for the Call
     expression to implement the SCall statement

   - compiling the left-hand-side of an assignment is almost exactly like
     compiling the Id or Index expression. Instead of loading the resulting
     pointer, you just need to store to it!

 *)

let rec cmp_stmt (c:Ctxt.t) (rt:Ll.ty) (stmt:Ast.stmt node) : Ctxt.t * stream =
  match stmt.elt with
    | Ret (Some e) -> 
      let t, op, exp_stream = cmp_exp c e in
      let r = T (Ret (t, Some op)) in
      (c, exp_stream >:: r)
    | Ret None -> (c, [T (Ret (Void, None))])
    | Decl (id, e1) ->
      let t, op, stream = cmp_exp c e1 in
      let slot_id = gensym id in
      let alloca_elt  = E (slot_id, Alloca t) in
      let store_elt = I (gensym "store", Store (t, op, Id slot_id)) in
      let new_c = Ctxt.add c id (Ptr t, Id slot_id) in
      (new_c,  stream >::alloca_elt >:: store_elt)
    | If (e, stmts1, stmts2) ->
      let t, op, stream = cmp_exp c e in
      
      let then_lbl = gensym "then_lbl" in
      let else_lbl = gensym "else_lbl" in
      let merge_lbl = gensym "merge_lbl" in
      
      let cond_br = T (Cbr (op, then_lbl, else_lbl)) in
      let uncon_br = T (Br merge_lbl) in


      let _, stream1 = cmp_block c rt stmts1 in
      let _, stream2 = cmp_block c rt stmts2 in
      
      let full_stream = 
        stream
        >:: cond_br
        >:: L then_lbl
        >@ stream1
        >:: uncon_br
        >:: L else_lbl
        >@ stream2
        >:: uncon_br
        >:: L merge_lbl
      in
      (c, full_stream)

    | For (vars, e, stmt, stmts) ->
      let init_stmts = List.map (fun d -> no_loc (Decl d)) vars in
      let cond = match e with
       | Some exp -> exp
       | None     -> no_loc (CBool true)
      in
      let loop_body = match stmt with
       | Some u -> stmts @ [u]
       | None   -> stmts
      in
      let while_stmt = no_loc (While (cond, loop_body)) in
      let _, stream = cmp_block c rt (init_stmts @ [while_stmt]) in
      (c, stream)
    | While (e, stmts)->
      let t, op, stream = cmp_exp c e in

      let body_lbl = gensym "body_lbl" in
      let cond_lbl = gensym "cond_lbl" in
      let merge_lbl = gensym "merge_lbl" in

      let cond_br = T (Cbr (op, body_lbl, merge_lbl)) in
      let uncon_br = T (Br cond_lbl) in

      let _, stream1 = cmp_block c rt stmts in

      let fullstream = 
        [L cond_lbl; uncon_br]
        >@ stream 
        >:: cond_br
        >:: L body_lbl
        >@ stream1 
        >:: uncon_br
        >:: L merge_lbl
      in

      (c, fullstream)
    | Assn (e1, e2) ->
      begin match e1.elt with
      | Id id ->
        let val_ty, val_op, rhs_stream = cmp_exp c e2 in
        let ptr_ty, ptr_op = Ctxt.lookup id c in
        let insn = I (gensym "store", Store (val_ty, val_op, ptr_op)) in
        (c, rhs_stream >:: insn)
      | Index (arr_exp, idx_exp) ->
        let elem_ty, ptr_op, ptr_str = cmp_index_ptr c arr_exp idx_exp in
        let val_ty, val_op, rhs_str = cmp_exp c e2 in
        let store_insn = I (gensym "store", Store (val_ty, val_op, ptr_op)) in
        (c, ptr_str >@ rhs_str >:: store_insn)
      | _ -> failwith "invalid lhs"
      end
    | SCall (fn_exp, args) ->
      let fname = match fn_exp.elt with
        | Id name -> name
        | _ -> failwith "fname expected"
      in
      let f_ty, f_op = Ctxt.lookup_function fname c in
      let ret_ty = match f_ty with
      | Ptr (Fun (_, r)) -> r
      | _ -> failwith "not a function"
      in
      let (args_ops, all_arg_streams) = List.fold_left (fun (ty_op, stream) arg->
        let arg_ty, arg_op, arg_stream = cmp_exp c arg in
        (ty_op @ [(arg_ty, arg_op)], stream >@ arg_stream)
        ) ([], []) args
      in
      let res_id = gensym "call" in
      let insn = I (res_id, Call (ret_ty, f_op, args_ops)) in
      (c, all_arg_streams >:: insn)
    | _ -> failwith "stmt not yet implemented"



(* Compile a series of statements *)
and cmp_block (c:Ctxt.t) (rt:Ll.ty) (stmts:Ast.block) : Ctxt.t * stream =
  List.fold_left (fun (c, code) s -> 
      let c, stmt_code = cmp_stmt c rt s in
      c, code >@ stmt_code
    ) (c,[]) stmts



(* Adds each function identifer to the context at an
   appropriately translated type.  

   NOTE: The Gid of a function is just its source name
*)
let cmp_function_ctxt (c:Ctxt.t) (p:Ast.prog) : Ctxt.t =
    List.fold_left (fun c -> function
      | Ast.Gfdecl { elt={ frtyp; fname; args } } ->
         let ft = TRef (RFun (List.map fst args, frtyp)) in
         Ctxt.add c fname (cmp_ty ft, Gid fname)
      | _ -> c
    ) c p 

(* Populate a context with bindings for global variables 
   mapping OAT identifiers to LLVMlite gids and their types.

   Only a small subset of OAT expressions can be used as global initializers
   in well-formed programs. (The constructors starting with C). 
*)
let const_to_Ty : (Ast.exp) -> (Ast.ty) = function
  | CInt _ -> TInt
  | CBool _ -> TBool
  | CStr _ -> TRef RString
  | CNull r -> TRef r
  | CArr (t, _) -> TRef (RArray t)
  | _ -> failwith "Invalid global initializer"


let cmp_global_ctxt (c:Ctxt.t) (p:Ast.prog) : Ctxt.t =
  List.fold_left (fun c -> function
    | Ast.Gvdecl { elt={ name; init} } ->
       Ctxt.add c name ( Ptr (cmp_ty(const_to_Ty init.elt)), Gid name)
    | _ -> c
  ) c p



(* Compile a function declaration in global context c. Return the LLVMlite cfg
   and a list of global declarations containing the string literals appearing
   in the function.

   You will need to
   1. Allocate stack space for the function parameters using Alloca
   2. Store the function arguments in their corresponding alloca'd stack slot
   3. Extend the context with bindings for function variables
   4. Compile the body of the function using cmp_block
   5. Use cfg_of_stream to produce a LLVMlite cfg from 
 *)

let cmp_fdecl (c:Ctxt.t) (f:Ast.fdecl node) : Ll.fdecl * (Ll.gid * Ll.gdecl) list =
  (*1*) let f_param = List.map snd f.elt.args in
  (*2*) let f_ty = cmp_fty (List.map fst f.elt.args, f.elt.frtyp) in
  (*3*) let (new_c, arg_stream) = List.fold_left (fun (con, list) (arg_ty, arg_id) -> 
          let slot_id = gensym arg_id in
          let ll_ty = cmp_ty arg_ty in 
          let alloca_elt = E (slot_id, Alloca ll_ty) in
          let store_elt = I (gensym "store", Store (ll_ty, Id arg_id, Id slot_id)) in
          let new_c1 = Ctxt.add con arg_id (Ptr ll_ty, Id slot_id) in
          let arg_stream1 = [ alloca_elt; store_elt ] in
          (new_c1, list >@ arg_stream1)
        ) (c, []) f.elt.args in
  (*4*) let _, body_stream = cmp_block new_c (cmp_ret_ty f.elt.frtyp) f.elt.body in
        let full_stream = arg_stream >@ body_stream in
  (*5*) let f_cfg, globals = cfg_of_stream full_stream in
        ({ f_ty; f_param; f_cfg }, globals)


(* Compile a global initializer, returning the resulting LLVMlite global
   declaration, and a list of additional global declarations.

   Tips:
   - Only CNull, CBool, CInt, CStr, and CArr can appear as global initializers
     in well-formed OAT programs. Your compiler may throw an error for the other
     cases

   - OAT arrays are always handled via pointers. A global array of arrays will
     be an array of pointers to arrays emitted as additional global declarations.
*)

let rec cmp_gexp c (e:Ast.exp node) : Ll.gdecl * (Ll.gid * Ll.gdecl) list =
  match e.elt with
  | CInt i -> ((I64, GInt i), [])
  | CBool b -> ((I1, GInt (if b then 1L else 0L)), [])
  | CNull r -> ((cmp_ty (TRef r), GNull), [])
  | CStr str -> 
    let raw_id = gensym "str" in
    let len = (String.length str)  + 1 in
    let ty = Array (len, I8) in
    let raw_var = (ty, GString str) in
    let raw_pointer = (Ptr I8, GBitcast (Ptr ty, GGid raw_id, Ptr I8)) in
    (raw_pointer, [(raw_id, raw_var)])
  | CArr (ty, es) ->
    let elts_gdecls, elts_extra = List.split (List.map (cmp_gexp c) es) in
    let len = List.length es in
    let elem_ty = cmp_ty ty in
    let raw_init = GStruct [
      (I64, GInt (Int64.of_int len));
      (Array (len, elem_ty), GArray elts_gdecls)
    ] in
    let raw_ty = Struct [ I64; Array (len, elem_ty) ] in
    let raw_id = gensym "global_arr" in
    let final_ty = cmp_ty (TRef (RArray ty)) in
    let raw_pointer = (final_ty, GBitcast (Ptr raw_ty, GGid raw_id, final_ty)) in
    (raw_pointer, (raw_id, (raw_ty, raw_init)) :: List.flatten elts_extra)



  | _ -> failwith "Strings and Arrays not yet implemented"
  

(* Oat internals function context ------------------------------------------- *)
let internals = [
    "oat_alloc_array",         Ll.Fun ([I64], Ptr I64)
  ]

(* Oat builtin function context --------------------------------------------- *)
let builtins =
  [ "array_of_string",  cmp_rty @@ RFun ([TRef RString], RetVal (TRef(RArray TInt)))
  ; "string_of_array",  cmp_rty @@ RFun ([TRef(RArray TInt)], RetVal (TRef RString))
  ; "length_of_string", cmp_rty @@ RFun ([TRef RString],  RetVal TInt)
  ; "string_of_int",    cmp_rty @@ RFun ([TInt],  RetVal (TRef RString))
  ; "string_cat",       cmp_rty @@ RFun ([TRef RString; TRef RString], RetVal (TRef RString))
  ; "print_string",     cmp_rty @@ RFun ([TRef RString],  RetVoid)
  ; "print_int",        cmp_rty @@ RFun ([TInt],  RetVoid)
  ; "print_bool",       cmp_rty @@ RFun ([TBool], RetVoid)
  ]

(* Compile a OAT program to LLVMlite *)
let cmp_prog (p:Ast.prog) : Ll.prog =
  (* add built-in functions to context *)
  let init_ctxt = 
    List.fold_left (fun c (i, t) -> Ctxt.add c i (Ll.Ptr t, Gid i))
      Ctxt.empty builtins
  in
  let fc = cmp_function_ctxt init_ctxt p in

  (* build global variable context *)
  let c = cmp_global_ctxt fc p in

  (* compile functions and global variables *)
  let fdecls, gdecls = 
    List.fold_right (fun d (fs, gs) ->
        match d with
        | Ast.Gvdecl { elt=gd } -> 
           let ll_gd, gs' = cmp_gexp c gd.init in
           (fs, (gd.name, ll_gd)::gs' @ gs)
        | Ast.Gfdecl fd ->
           let fdecl, gs' = cmp_fdecl c fd in
           (fd.elt.fname,fdecl)::fs, gs' @ gs
      ) p ([], [])
  in

  (* gather external declarations *)
  let edecls = internals @ builtins in
  { tdecls = []; gdecls; fdecls; edecls }

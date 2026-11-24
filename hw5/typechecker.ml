open Ast
open Astlib
open Tctxt

(* Error Reporting ---------------------------------------------------------- *)
(* NOTE: Use type_error to report error messages for ill-typed programs. *)

exception TypeError of string

let type_error (l : 'a node) err = 
  let (_, (s, e), _) = l.loc in
  raise (TypeError (Printf.sprintf "[%d, %d] %s" s e err))


(* initial context: G0 ------------------------------------------------------ *)
(* The Oat types of the Oat built-in functions *)
let builtins =
  [ "array_of_string",  ([TRef RString],  RetVal (TRef(RArray TInt)))
  ; "string_of_array",  ([TRef(RArray TInt)], RetVal (TRef RString))
  ; "length_of_string", ([TRef RString],  RetVal TInt)
  ; "string_of_int",    ([TInt], RetVal (TRef RString))
  ; "string_cat",       ([TRef RString; TRef RString], RetVal (TRef RString))
  ; "print_string",     ([TRef RString],  RetVoid)
  ; "print_int",        ([TInt], RetVoid)
  ; "print_bool",       ([TBool], RetVoid)
  ]

(* binary operation types --------------------------------------------------- *)
let typ_of_binop : Ast.binop -> Ast.ty * Ast.ty * Ast.ty = function
  | Add | Mul | Sub | Shl | Shr | Sar | IAnd | IOr -> (TInt, TInt, TInt)
  | Lt | Lte | Gt | Gte -> (TInt, TInt, TBool)
  | And | Or -> (TBool, TBool, TBool)
  | Eq | Neq -> failwith "typ_of_binop called on polymorphic == or !="

(* unary operation types ---------------------------------------------------- *)
let typ_of_unop : Ast.unop -> Ast.ty * Ast.ty = function
  | Neg | Bitnot -> (TInt, TInt)
  | Lognot       -> (TBool, TBool)

(* subtyping ---------------------------------------------------------------- *)
(* Decides whether H |- t1 <: t2 
    - assumes that H contains the declarations of all the possible struct types

    - you will want to introduce addition (possibly mutually recursive) 
      helper functions to implement the different judgments of the subtyping
      relation. We have included a template for subtype_ref to get you started.
      (Don't forget about OCaml's 'and' keyword.)
*)
let rec subtype (c : Tctxt.t) (t1 : Ast.ty) (t2 : Ast.ty) : bool =
  match t1, t2 with
  | TInt, TInt -> true
  | TBool, TBool -> true
  | TRef rty1, TRef rty2 -> subtype_ref c rty1 rty2
  | TRef rty1, TNullRef rty2 -> subtype_ref c rty1 rty2
  | TNullRef rty1, TNullRef rty2 -> subtype_ref c rty1 rty2
  | _  -> false
    

(* Decides whether H |-r ref1 <: ref2 *)
and subtype_ref (c : Tctxt.t) (t1 : Ast.rty) (t2 : Ast.rty) : bool =
  match t1, t2 with
  | RString, RString -> true
  | RArray ty1, RArray ty2 -> ty1 = ty2
  | RStruct s1, RStruct s2 ->
    let f1 = lookup_struct_option s1 c in
    let f2 = lookup_struct_option s2 c in
    let rec is_prefix f1 f2 = 
      match f1, f2 with
      | _, [] -> true
      | x :: xs, y :: ys ->
        (x = y) && is_prefix xs ys
      | [], _ :: _ -> false
    in
    (match f1, f2 with
    | Some fields1, Some fields2 -> is_prefix fields1 fields2
    | _ -> false)
  | RFun (args1, ret1), RFun (args2, ret2) ->
    let rec comp args1 args2 = 
      match args1, args2 with
      | [], [] -> true
      | x::xs, y::ys ->
        subtype c y x && comp xs ys
      | _ -> false
    in
    comp args1 args2 && subtype_ret c ret1 ret2
  | _  -> false
    

and subtype_ret (c : Tctxt.t) (t1 : Ast.ret_ty) (t2 : Ast.ret_ty) : bool =
  match t1, t2 with
  | RetVoid, RetVoid -> true
  | RetVal ty1, RetVal ty2 -> subtype c ty1 ty2
  | _ -> false


(* well-formed types -------------------------------------------------------- *)
(* Implement a (set of) functions that check that types are well formed according
   to the H |- t and related inference rules

    - the function should succeed by returning () if the type is well-formed
      according to the rules

    - the function should fail using the "type_error" helper function if the 
      type is not well-formed

    - l is just an ast node that provides source location information for
      generating error messages (it's only needed for the type_error generation)

    - tc contains the structure definition context
 *)
let rec typecheck_ty (l : 'a Ast.node) (tc : Tctxt.t) (t : Ast.ty) : unit =
  match t with
  | TInt -> ()
  | TBool -> ()
  | TRef rty -> typecheck_ref l tc rty 
  | TNullRef rty -> typecheck_ref l tc rty 
  | _ -> type_error l "type is not well-formed"

and typecheck_ref (l : 'a Ast.node) (tc : Tctxt.t) (t : Ast.rty) : unit =
  match t with
  | RString -> ()
  | RArray ty -> typecheck_ty l tc ty
  | RStruct id -> 
    (match lookup_struct_option id tc with
    | Some _ -> ()
    | None -> type_error l "undefined struct")
  | RFun (args1, ret1) ->
    List.iter (typecheck_ty l tc) args1;
    typecheck_ret l tc ret1
  | _ -> type_error l "type is not well-formed"

  and typecheck_ret (l : 'a Ast.node) (tc : Tctxt.t) (t : Ast.ret_ty) : unit =
    match t with 
    | RetVoid -> ()
    | RetVal ty1 -> typecheck_ty l tc ty1
    | _ -> type_error l "type is not well-formed"


(* typechecking expressions ------------------------------------------------- *)
(* Typechecks an expression in the typing context c, returns the type of the
   expression.  This function should implement the inference rules given in the
   oad.pdf specification.  There, they are written:

       H; G; L |- exp : t

   See tctxt.ml for the implementation of the context c, which represents the
   four typing contexts: H - for structure definitions G - for global
   identifiers L - for local identifiers

   Returns the (most precise) type for the expression, if it is type correct
   according to the inference rules.

   Uses the type_error function to indicate a (useful!) error message if the
   expression is not type correct.  The exact wording of the error message is
   not important, but the fact that the error is raised, is important.  (Our
   tests also do not check the location information associated with the error.)

   Notes: - Structure values permit the programmer to write the fields in any
   order (compared with the structure definition).  This means that, given the
   declaration struct T { a:int; b:int; c:int } The expression new T {b=3; c=4;
   a=1} is well typed.  (You should sort the fields to compare them.)

*)
let rec typecheck_exp (c : Tctxt.t) (e : Ast.exp node) : Ast.ty =
  match e.elt with
    | Bop (bop, e1, e2) ->
      let ty1 = typecheck_exp c e1 in
      let ty2 = typecheck_exp c e2 in
      (match bop with
      | Eq | Neq -> 
        if (subtype c ty1 ty2 &&  subtype c ty2 ty1) then TBool
        else type_error e "types are not comparable"
      | _ ->
        let (arg1, arg2, out) = typ_of_binop bop in
        if ty1 <> arg1 then type_error e "left exp is not well typed" 
        else 
        if ty2 <> arg2 then type_error e "right exp is not well typed"
        else out)
    | Uop (uop, e) ->
      let t = typecheck_exp c e in
      let (arg, out) = typ_of_unop uop in
      if t <> arg then type_error e "Uop is not well typed" 
      else out
    | CNull rty -> 
      typecheck_ref e c rty;
      TNullRef rty
    | CBool _ -> TBool
    | CInt _ -> TInt
    | CStr _ -> TRef RString
    | Id t -> 
      (match lookup_option t c with
      | Some ty -> ty
      | None -> type_error e "Id is not well typed")
    | CArr (t, es) -> 
      typecheck_ty e c t;
      let ts = List.map (typecheck_exp c ) es in
      if (List.for_all (fun x -> subtype c x t) ts) then 
        TRef (RArray t) 
      else 
        type_error e "array element type mismatch"
    | NewArr (ty, e1, id, e2) ->
      typecheck_ty e c ty;
      (match typecheck_exp c e1 with
      | TInt -> 
        (match lookup_local_option id c with
        | None -> 
          let cnew = add_local c id TInt in
          let t = typecheck_exp cnew e2 in
          if subtype c t ty then 
            TRef (RArray ty)
          else 
            type_error e "array initializer type does not match element type"
        | _ -> type_error e "index expr is already a local var")
      | _ -> type_error e "index expr is not an int")
    | Index (e1, e2) -> 
      (match typecheck_exp c e1 with
        | TRef (RArray t) ->
          (match typecheck_exp c e2 with
          | TInt -> t
          | _ -> type_error e "index expr is not an int")
        | _ -> type_error e "expr is not an an array")
    | Length e ->
      (match typecheck_exp c e with
        | TRef (RArray t) -> TInt
        | _ -> type_error e "expr is not an an array")
    | CStruct (id, fields)->
      (match lookup_struct_option id c with
        | Some ts -> 
          let rec comp tys1 tys2 = 
            (match tys1, tys2 with
            | [], [] -> true
            | x::xs, (yname, yexp)::ys ->
              (x.fieldName = yname) && subtype c (typecheck_exp c yexp) x.ftyp && comp xs ys
            | _ -> false)
          in
          if (List.length fields <> List.length ts) 
            then type_error e "expression list and type list length unequal"
          else
            let tsorted = List.sort (fun f1 f2 -> String.compare f1.fieldName f2.fieldName) ts in
            let texpsorted = List.sort (fun (n1, _) (n2, _) -> String.compare n1 n2) fields in
            if (comp tsorted texpsorted) then 
              TRef (RStruct id)
            else
              type_error e "expressions do not match struct types"
        | None -> type_error e "struct not in lookup table"
        )
    | Proj (e, x) ->
      (match typecheck_exp c e with
      | TRef (RStruct s) ->
        (match lookup_field_option s x c with
        | Some t -> 
          t
        | _ -> type_error e "field not found in struct")
      | _ -> type_error e "projection expr is not a struct")
    | Call (fn_exp, es) ->
      (match typecheck_exp c fn_exp with
      | TRef (RFun (tys, ret_ty)) -> 
        let tysexp = List.map (typecheck_exp c) es in
        let rec comp arg1 arg2 = 
          (match arg1, arg2 with
          | [], [] -> true
          | x :: xs, y :: ys -> 
            subtype c x y && comp xs ys
          | _ -> false )
        in
        if (comp tysexp tys) then
          (match ret_ty with
            | RetVal t -> t
            | RetVoid -> type_error e "function returns void and cannot be used as an expression")
        else 
          type_error e "expr args not subtype of call args"
      | _ -> type_error e "expr does not match func type")
    



(* statements ------------- -------------------------------------------------- *)

(* Typecheck a statement 
   This function should implement the statement typechecking rules from oat.pdf.  

   Inputs:
    - tc: the type context
    - s: the statement node
    - to_ret: the desired return type (from the function declaration)

   Returns:
     - the new type context (which includes newly declared variables in scope
       after this statement
     - A boolean indicating the return behavior of a statement:
        false:  might not return
        true: definitely returns 

        in the branching statements, both branches must definitely return

        Intuitively: if one of the two branches of a conditional does not 
        contain a return statement, then the entier conditional statement might 
        not return.
  
        looping constructs never definitely return 

   Uses the type_error function to indicate a (useful!) error message if the
   statement is not type correct.  The exact wording of the error message is
   not important, but the fact that the error is raised, is important.  (Our
   tests also do not check the location information associated with the error.)

   - You will probably find it convenient to add a helper function that implements the 
     block typecheck rules.
*)
let rec typecheck_stmt (tc : Tctxt.t) (s:Ast.stmt node) (to_ret:ret_ty) : Tctxt.t * bool =
  failwith "todo: implement typecheck_stmt"


(* struct type declarations ------------------------------------------------- *)
(* Here is an example of how to implement the TYP_TDECLOK rule, which is 
   is needed elswhere in the type system.
 *)

(* Helper function to look for duplicate field names *)
let rec check_dups fs =
  match fs with
  | [] -> false
  | h :: t -> (List.exists (fun x -> x.fieldName = h.fieldName) t) || check_dups t

let typecheck_tdecl (tc : Tctxt.t) id fs  (l : 'a Ast.node) : unit =
  if check_dups fs
  then type_error l ("Repeated fields in " ^ id) 
  else List.iter (fun f -> typecheck_ty l tc f.ftyp) fs

(* function declarations ---------------------------------------------------- *)
(* typecheck a function declaration 
    - extends the local context with the types of the formal parameters to the 
      function
    - typechecks the body of the function (passing in the expected return type
    - checks that the function actually returns
*)
let rec check_dups_f args =
  match args with
  | [] -> false
  | h :: t -> 
    let (ty, id) = h in
    (List.exists (fun x -> 
      let (ty1, id1) = x in
      id1 = id) t) || check_dups_f t

let typecheck_fdecl (tc : Tctxt.t) (f : Ast.fdecl) (l : 'a Ast.node) : unit =
  failwith "todo"


(* creating the typchecking context ----------------------------------------- *)

(* The following functions correspond to the
   judgments that create the global typechecking context.

   create_struct_ctxt: - adds all the struct types to the struct 'H'
   context (checking to see that there are no duplicate fields

     H |-s prog ==> H'


   create_function_ctxt: - adds the the function identifiers and their
   types to the 'G' context (ensuring that there are no redeclared
   function identifiers)

     H ; G1 |-f prog ==> G2


   create_global_ctxt: - typechecks the global initializers and adds
   their identifiers to the 'G' global context

     H ; G1 |-g prog ==> G2    


   NOTE: global initializers may mention function identifiers as
   constants, but can't mention other global values *)

let create_struct_ctxt (p:Ast.prog) : Tctxt.t =
  let c = Tctxt.empty in
  List.fold_left (fun acc_c decl ->
    match decl with 
    | Gtdecl td ->
      let (id, fields) = td.elt in
      (match lookup_struct_option id acc_c with
       | Some _ -> type_error td "struct already in context"
       | None -> 
        if (check_dups fields) then
          type_error td "struct contains duplicate fields"
        else
          add_struct acc_c id fields)
    | _ -> acc_c
    ) c p

let create_function_ctxt (tc:Tctxt.t) (p:Ast.prog) : Tctxt.t =
  let c_builtin = List.fold_left (fun acc_c (fname, (args, ret)) ->
    add_global acc_c fname (TRef(RFun(args, ret)))
    ) tc builtins
  in
  List.fold_left (fun acc_c decl ->
    match decl with 
    | Gfdecl fd ->
      let fname = fd.elt.fname in
      let args = fd.elt.args in
      let frtyp = fd.elt.frtyp in
      (match lookup_global_option fname acc_c with
      | Some _ -> type_error fd "func already in context"
      | None -> 
        if (check_dups_f args) then
          type_error fd "func contains duplicate args"
        else
          let f_ty = TRef (RFun (List.map fst args, frtyp)) in
          add_global acc_c fname f_ty)
    | _ -> acc_c
    ) c_builtin p

let create_global_ctxt (tc:Tctxt.t) (p:Ast.prog) : Tctxt.t =
 List.fold_left (fun acc_c decl ->
    match decl with 
    | Gvdecl gd ->
      let x = gd.elt.name in
      let gexp = gd.elt.init in
      let t = typecheck_exp tc gexp in
      (match lookup_global_option x acc_c with
      | Some _ -> type_error gd "var already in context"
      | None -> add_global acc_c x t)
    | _ -> acc_c 
  ) tc p 


(* This function implements the |- prog and the H ; G |- prog 
   rules of the oat.pdf specification.   
*)
let typecheck_program (p:Ast.prog) : unit =
  let sc = create_struct_ctxt p in
  let fc = create_function_ctxt sc p in
  let tc = create_global_ctxt fc p in
  List.iter (fun p ->
    match p with
    | Gfdecl ({elt=f} as l) -> typecheck_fdecl tc f l
    | Gtdecl ({elt=(id, fs)} as l) -> typecheck_tdecl tc id fs l 
    | _ -> ()) p

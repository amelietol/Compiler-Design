(* X86lite Simulator *)

(* See the documentation in the X86lite specification, available on the 
   course web pages, for a detailed explanation of the instruction
   semantics.
*)

open X86

(* simulator machine state -------------------------------------------------- *)

let mem_bot = 0x400000L          (* lowest valid address *)
let mem_top = 0x410000L          (* one past the last byte in memory *)
let mem_size = Int64.to_int (Int64.sub mem_top mem_bot)
let nregs = 17                   (* including Rip *)
let ins_size = 8L                (* assume we have a 8-byte encoding *)
let exit_addr = 0xfdeadL         (* halt when m.regs(%rip) = exit_addr *)

(* Your simulator should raise this exception if it tries to read from or
   store to an address not within the valid address space. *)
exception X86lite_segfault

(* The simulator memory maps addresses to symbolic bytes.  Symbolic
   bytes are either actual data indicated by the Byte constructor or
   'symbolic instructions' that take up eight bytes for the purposes of
   layout.

   The symbolic bytes abstract away from the details of how
   instructions are represented in memory.  Each instruction takes
   exactly eight consecutive bytes, where the first byte InsB0 stores
   the actual instruction, and the next seven bytes are InsFrag
   elements, which aren't valid data.

   For example, the two-instruction sequence:
        at&t syntax             ocaml syntax
      movq %rdi, (%rsp)       Movq,  [~%Rdi; Ind2 Rsp]
      decq %rdi               Decq,  [~%Rdi]

   is represented by the following elements of the mem array (starting
   at address 0x400000):

       0x400000 :  InsB0 (Movq,  [~%Rdi; Ind2 Rsp])
       0x400001 :  InsFrag
       0x400002 :  InsFrag
       0x400003 :  InsFrag
       0x400004 :  InsFrag
       0x400005 :  InsFrag
       0x400006 :  InsFrag
       0x400007 :  InsFrag
       0x400008 :  InsB0 (Decq,  [~%Rdi])
       0x40000A :  InsFrag
       0x40000B :  InsFrag
       0x40000C :  InsFrag
       0x40000D :  InsFrag
       0x40000E :  InsFrag
       0x40000F :  InsFrag
       0x400010 :  InsFrag
*)
type sbyte = InsB0 of ins       (* 1st byte of an instruction *)
           | InsFrag            (* 2nd - 8th bytes of an instruction *)
           | Byte of char       (* non-instruction byte *)

(* memory maps addresses to symbolic bytes *)
type mem = sbyte array

(* Flags for condition codes *)
type flags = { mutable fo : bool
             ; mutable fs : bool
             ; mutable fz : bool
             }

(* Register files *)
type regs = int64 array

(* Complete machine state *)
type mach = { flags : flags
            ; regs : regs
            ; mem : mem
            }

(* simulator helper functions ----------------------------------------------- *)

(* The index of a register in the regs array *)
let rind : reg -> int = function
  | Rip -> 16
  | Rax -> 0  | Rbx -> 1  | Rcx -> 2  | Rdx -> 3
  | Rsi -> 4  | Rdi -> 5  | Rbp -> 6  | Rsp -> 7
  | R08 -> 8  | R09 -> 9  | R10 -> 10 | R11 -> 11
  | R12 -> 12 | R13 -> 13 | R14 -> 14 | R15 -> 15

(* Helper functions for reading/writing sbytes *)

(* Convert an int64 to its sbyte representation *)
let sbytes_of_int64 (i:int64) : sbyte list =
  let open Char in 
  let open Int64 in
  List.map (fun n -> Byte (shift_right i n |> logand 0xffL |> to_int |> chr))
           [0; 8; 16; 24; 32; 40; 48; 56]

(* Convert an sbyte representation to an int64 *)
let int64_of_sbytes (bs:sbyte list) : int64 =
  let open Char in
  let open Int64 in
  let f b i = match b with
    | Byte c -> logor (shift_left i 8) (c |> code |> of_int)
    | _ -> 0L
  in
  List.fold_right f bs 0L

(* Convert a string to its sbyte representation *)
let sbytes_of_string (s:string) : sbyte list =
  let rec loop acc = function
    | i when i < 0 -> acc
    | i -> loop (Byte s.[i]::acc) (pred i)
  in
  loop [Byte '\x00'] @@ String.length s - 1

(* Serialize an instruction to sbytes *)
let sbytes_of_ins (op, args:ins) : sbyte list =
  let check = function
    | Imm (Lbl _) | Ind1 (Lbl _) | Ind3 (Lbl _, _) -> 
      invalid_arg "sbytes_of_ins: tried to serialize a label!"
    | o -> ()
  in
  List.iter check args;
  [InsB0 (op, args); InsFrag; InsFrag; InsFrag;
   InsFrag; InsFrag; InsFrag; InsFrag]

(* Serialize a data element to sbytes *)
let sbytes_of_data : data -> sbyte list = function
  | Quad (Lit i) -> sbytes_of_int64 i
  | Asciz s -> sbytes_of_string s
  | Quad (Lbl _) -> invalid_arg "sbytes_of_data: tried to serialize a label!"


(* It might be useful to toggle printing of intermediate states of your 
   simulator. Our implementation uses this mutable flag to turn on/off
   printing.  For instance, you might write something like:

     [if !debug_simulator then print_endline @@ string_of_ins u; ...]

*)
let debug_simulator = ref false

(* Interpret a condition code with respect to the given flags. *)
let interp_cnd {fo; fs; fz} : cnd -> bool = fun x ->
  match x with
   |Eq -> fz = true
   |Neq -> fz = false
   |Gt -> fs = fo && fz = false
   |Ge -> fs = fo
   |Lt ->  fs <> fo
   |Le -> (fs<>fo) || fz=true



(* Maps an X86lite address into Some OCaml array index,
   or None if the address is not within the legal address space. *)
let map_addr (addr:quad) : int option =
  if (addr>=mem_bot &&  addr<mem_top) then
    let array_index = Int64.to_int (Int64.sub addr mem_bot) in
    Some array_index
  else
    None

(*interpretaion of operands*)
(* Evaluates an operand to return its current 64-bit value *)


(* Helper function to read an 8-byte int64 from memory *)
let read_mem (m:mach) (addr:quad) : int64 =
  (* Check that BOTH the start and end of the 8-byte chunk are valid *)
  match map_addr addr, map_addr (Int64.add addr 7L) with
  | Some i, Some _ -> 
      let bytes = [ m.mem.(i);   m.mem.(i+1); m.mem.(i+2); m.mem.(i+3);
                    m.mem.(i+4); m.mem.(i+5); m.mem.(i+6); m.mem.(i+7) ] in
      int64_of_sbytes bytes
  | _ -> 
      raise X86lite_segfault

(* Helper function to write an 8-byte int64 to memory *)
let write_mem (m:mach) (addr:quad) (v:int64) : unit =
  (* Check that BOTH the start and end of the 8-byte chunk are valid *)
  match map_addr addr, map_addr (Int64.add addr 7L) with
  | Some i, Some _ -> 
      let bytes = sbytes_of_int64 v in
      List.iteri (fun offset byte -> m.mem.(i + offset) <- byte) bytes
  | _ -> 
      raise X86lite_segfault

(* Helper function to write a value to a destination operand *)
let write_op (m:mach) (dest:operand) (v:int64) : unit =
  match dest with
  | Reg r -> 
      m.regs.(rind r) <- v
  | Ind1 (Lit i) -> 
      write_mem m i v
  | Ind2 r -> 
      write_mem m (m.regs.(rind r)) v
  | Ind3 (Lit i, r) -> 
      let base_addr = m.regs.(rind r) in
      write_mem m (Int64.add base_addr i) v
  | _ -> 
      failwith "Invalid destination operand (cannot write to Immediate or Label)"


let interp (m:mach) (x:operand) : int64 =
  match x with
  | Imm (Lit i) -> 
      i
  | Imm (Lbl _) -> 
      failwith "Labels should have been resolved during assembly"
  | Reg r -> 
      m.regs.(rind r)
  | Ind1 (Lit i) -> 
      read_mem m i
  | Ind1 (Lbl _) -> 
      failwith "Labels should have been resolved during assembly"
  | Ind2 r -> 
      read_mem m (m.regs.(rind r))
  | Ind3 (Lit i, r) -> 
      let base_addr = m.regs.(rind r) in
      read_mem m (Int64.add base_addr i)
  | Ind3 (Lbl _, _) -> 
      failwith "Labels should have been resolved during assembly"


(* Simulates one step of the machine:
    - fetch the instruction at %rip
    - compute the source and/or destination information from the operands
    - simulate the instruction semantics
    - update the registers and/or memory appropriately
    - set the condition flags
*)
let step (m:mach) : unit =
  (* 1. FETCH: Get current instruction pointer value *)
  let rip_val = m.regs.(rind Rip) in

  let (opcode, args) =
    match map_addr rip_val with
      | Some i ->
        (match m.mem.(i) with
          | InsB0(opcode, args) -> (opcode, args)
          | _ -> failwith "invalid instruction at %rip")
      | None -> raise X86lite_segfault
      in
    

  m.regs.(rind Rip) <- Int64.add rip_val 8L;

  let set_flags {Int64_overflow.value; overflow} =
    m.flags.fo <- overflow;
    m.flags.fs <- (value < 0L);
    m.flags.fz <- (value = 0L)
  in

  
  match (opcode, args) with
   | Movq, [src; dst] -> write_op m dst (interp m src)
   | Leaq, [ind; dst] -> 
      let addr = 
        match ind with
          | Ind1 (Lit i) -> i
          | Ind2 r -> m.regs.(rind r)
          | Ind3 (Lit offset, r) -> Int64.add offset m.regs.(rind r)
          | _ -> failwith "invalid leaq source (must be Ind)"
      in
      write_op m dst addr
  (*Arithmetic*)
   | Addq, [src; dst] ->
      let src_val = interp m src in
      let dst_val = interp m dst in
      let res = Int64_overflow.add src_val dst_val in
      set_flags res;
      write_op m dst res.value

   | Subq, [src; dst] ->
      let src_val = interp m src in
      let dst_val = interp m dst in
      let res = Int64_overflow.sub dst_val src_val in
      set_flags res;
      write_op m dst res.value
   | Imulq, [src; dst] ->
      let src_val = interp m src in
      let dst_val = interp m dst in
      let res = Int64_overflow.mul src_val dst_val in
      set_flags res;
      write_op m dst res.value

   | Andq, [src; dst] ->
      let src_val = interp m src in
      let dst_val = interp m dst in
      let res = Int64.logand src_val dst_val in
      m.flags.fo <- false;
      m.flags.fs <- (res < 0L);
      m.flags.fz <- (res = 0L); 
      write_op m dst res

   | Orq, [src; dst] ->
      let src_val = interp m src in
      let dst_val = interp m dst in
      let res = Int64.logor src_val dst_val in
      m.flags.fo <- false;
      m.flags.fs <- (res < 0L);
      m.flags.fz <- (res = 0L); 
      write_op m dst res

   | Xorq, [src; dst] ->
      let src_val = interp m src in
      let dst_val = interp m dst in
      let res = Int64.logxor src_val dst_val in
      m.flags.fo <- false;
      m.flags.fs <- (res < 0L);
      m.flags.fz <- (res = 0L); 
      write_op m dst res

  (*Unary Operations*)
   | Incq, [src] ->
      let src_val = interp m src in
      let res = Int64_overflow.succ src_val in
      set_flags res;
      write_op m src res.value

   | Decq, [src] ->
      let src_val = interp m src in
      let res = Int64_overflow.pred src_val in
      set_flags res;
      write_op m src res.value

   | Negq, [src] ->
      let src_val = interp m src in
      let res = Int64_overflow.neg src_val in
      set_flags res;
      write_op m src res.value
   | Notq, [src] ->
      let src_val = interp m src in
      let res = Int64.lognot src_val in
      write_op m src res
  
    (*shifts*)
   | Shlq, [amt; dst] ->
      let n = Int64.to_int (interp m amt) in
      let dst_val = interp m dst in
      let res = Int64.shift_left dst_val n in
      if (n > 0) then(
        m.flags.fz <- (res = 0L);
        m.flags.fs <- (res < 0L)
        );
      write_op m dst res
   | Sarq, [amt; dst] ->
      let n = Int64.to_int (interp m amt) in
      let dst_val = interp m dst in
      let res = Int64.shift_right dst_val n in
      if (n > 0) then(
        m.flags.fz <- (res = 0L);
        m.flags.fs <- (res < 0L)
        );
      write_op m dst res
   | Shrq, [amt; dst] ->
      let n = Int64.to_int (interp m amt) in
      let dst_val = interp m dst in
      let res = Int64.shift_right_logical dst_val n in
      if (n > 0) then(
        m.flags.fz <- (res = 0L);
        m.flags.fs <- (res < 0L)
        );
      write_op m dst res
(*Stack Operations*)
   | Pushq, [src] ->
      let current_rsp = m.regs.(rind Rsp) in
      m.regs.(rind Rsp) <- Int64.sub current_rsp 8L;
      write_mem m (m.regs.(rind Rsp)) (interp m src)

   | Popq, [dest] ->
      let v = read_mem m m.regs.(rind Rsp) in
      m.regs.(rind Rsp) <- Int64.add m.regs.(rind Rsp) 8L;
      write_op m dest v

(*Comparisons and Conditions*)
   | Cmpq, [src; dst] ->
      let src_val = interp m src in
      let dst_val = interp m dst in
      let res = Int64_overflow.sub dst_val src_val in
      set_flags res

   | Set cnd, [dst] ->
      let old_val = interp m dst in
      let cleared = Int64.logand old_val (Int64.lognot 0xFFL) in
      let byte_val = if interp_cnd m.flags cnd then 1L else 0L in
      let new_val = Int64.logor cleared byte_val in
      write_op m dst new_val
(*Control Flow*)
   
   | Jmp, [target] ->
      m.regs.(rind Rip) <- interp m target
   | J cnd, [target] ->
      if interp_cnd m.flags cnd then m.regs.(rind Rip) <- interp m target
   | Callq, [target] ->
      let new_rsp = Int64.sub m.regs.(rind Rsp) 8L in
      m.regs.(rind Rsp) <- new_rsp;
      write_mem m new_rsp m.regs.(rind Rip);
      m.regs.(rind Rip) <- interp m target

   | Retq, [] ->
      let return_addr = read_mem m m.regs.(rind Rsp) in
      m.regs.(rind Rsp) <- Int64.add m.regs.(rind Rsp) 8L;
      m.regs.(rind Rip) <- return_addr

    | _ -> failwith "unknown or invalid instruction"

  
(* Runs the machine until the rip register reaches a designated
   memory address. Returns the contents of %rax when the 
   machine halts. *)
let run (m:mach) : int64 = 
  while m.regs.(rind Rip) <> exit_addr do step m done;
  m.regs.(rind Rax)

(* assembling and linking --------------------------------------------------- *)

(* A representation of the executable *)
type exec = { entry    : quad              (* address of the entry point *)
            ; text_pos : quad              (* starting address of the code *)
            ; data_pos : quad              (* starting address of the data *)
            ; text_seg : sbyte list        (* contents of the text segment *)
            ; data_seg : sbyte list        (* contents of the data segment *)
            }

(* Assemble should raise this when a label is used but not defined *)
exception Undefined_sym of lbl

(* Assemble should raise this when a label is defined more than once *)
exception Redefined_sym of lbl

(* Convert an X86 program into an object file:
   - separate the text and data segments
   - compute the size of each segment
      Note: the size of an Asciz string section is (1 + the string length)
            due to the null terminator

   - resolve the labels to concrete addresses and 'patch' the instructions to 
     replace Lbl values with the corresponding Imm values.

   - the text segment starts at the lowest address
   - the data segment starts after the text segment

  HINT: List.fold_left and List.fold_right are your friends.
 *)
let assemble (p:prog) : exec =
  let text_pos = 0x400000L in
  let is_text e = match e.asm with Text _ -> true | Data _ -> false in
  let text_elems = List.filter is_text p in
  let data_elems = List.filter (fun e -> not (is_text e)) p in  

   let (data_pos, sym_tab_after_text) =
    let process_text (addr, sym_tab) e =
      if List.mem_assoc e.lbl sym_tab then
        raise (Redefined_sym e.lbl);
      let ins_list = match e.asm with Text is -> is | _ -> [] in
      let size = Int64.of_int (List.length ins_list * 8) in
      let new_addr = Int64.add addr size in
      let new_sym_tab = (e.lbl, addr) :: sym_tab in
      (new_addr, new_sym_tab)
    in
    List.fold_left process_text (text_pos, []) text_elems
  in

  let size_of_data = function
    | Quad _  -> 8L
    | Asciz s -> Int64.of_int (String.length s + 1)
  in
  
  let (_, full_sym_tab) =
    let process_data (addr, sym_tab) e =
      if List.mem_assoc e.lbl sym_tab then
        raise (Redefined_sym e.lbl);
      let data_list = match e.asm with Data ds -> ds | _ -> [] in
      let block_size = List.fold_left (fun acc d -> Int64.add acc (size_of_data d)) 0L data_list in
      let new_addr = Int64.add addr block_size in
      let new_sym_tab = (e.lbl, addr) :: sym_tab in
      (new_addr, new_sym_tab)
    in
    List.fold_left process_data (data_pos, sym_tab_after_text) data_elems
  in

  let entry = 
    match List.assoc_opt "main" full_sym_tab with
    | Some addr -> addr
    | None      -> raise (Undefined_sym "main")
  in

  let resolve_lbl l =
    match List.assoc_opt l full_sym_tab with
    | Some addr -> addr
    | None      -> raise (Undefined_sym l)
  in

  let resolve_op = function
    | Imm (Lbl l)     -> Imm (Lit (resolve_lbl l))
    | Ind1 (Lbl l)    -> Ind1 (Lit (resolve_lbl l))
    | Ind3 (Lbl l, r) -> Ind3 (Lit (resolve_lbl l), r)
    | other_op        -> other_op
  in


  let serialize_ins (op, args) =
    sbytes_of_ins (op, List.map resolve_op args)
  in
  let text_seg =
    List.concat_map (fun e ->
      match e.asm with
      | Text is -> List.concat_map serialize_ins is
      | _ -> []
    ) text_elems
  in

  let serialize_data = function
    | Quad (Lbl l) -> sbytes_of_data (Quad (Lit (resolve_lbl l)))
    | d            -> sbytes_of_data d
  in
  let data_seg =
    List.concat_map (fun e ->
      match e.asm with
      | Data ds -> List.concat_map serialize_data ds
      | _ -> []
    ) data_elems
  in

  { entry; text_pos; data_pos; text_seg; data_seg }

(* Convert an object file into an executable machine state. 
    - allocate the mem array
    - set up the memory state by writing the symbolic bytes to the 
      appropriate locations 
    - create the inital register state
      - initialize rip to the entry point address
      - initializes rsp to the last word in memory 
      - the other registers are initialized to 0
    - the condition code flags start as 'false'

  Hint: The Array.make, Array.blit, and Array.of_list library functions 
  may be of use.
*)
let load {entry; text_pos; data_pos; text_seg; data_seg} : mach = 
  let mem = Array.make mem_size (Byte '\x00') in
  let text_posInd = 
    match map_addr text_pos with Some i -> i | None -> raise X86lite_segfault in
  List.iteri (fun offset txt -> mem.(text_posInd + offset) <- txt) text_seg;
  let data_posInd = 
    match map_addr data_pos with Some i -> i | None -> raise X86lite_segfault in
  List.iteri (fun offset dta -> mem.(data_posInd + offset) <- dta) data_seg;

  let regs = Array.make nregs 0L in
  regs.(rind Rip) <- entry;

  let stack_top = Int64.sub mem_top 8L in
  
  regs.(rind Rsp) <- stack_top;
  
  let stack_idx = match map_addr stack_top with Some i -> i | None -> raise X86lite_segfault in
  List.iteri (fun offset adr -> mem.(stack_idx + offset) <- adr) (sbytes_of_int64 exit_addr);

  let flags = { fo = false; fs = false; fz = false } in
  { flags; regs; mem }



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
  
  (* Look up the instruction in memory *)
  let (opcode, args) = 
    match map_addr rip_val with
    | Some i -> 
        (match m.mem.(i) with
         | InsB0 (op, a) -> (op, a)
         | _ -> failwith "Execution error: %rip does not point to a valid InsB0")
    | None -> 
        raise X86lite_segfault 
  in

  (* 2. ADVANCE: Increment %rip by 8 (the instruction size) BEFORE executing *)
  m.regs.(rind Rip) <- Int64.add rip_val 8L;

  (* 3. DECODE & EXECUTE: Match on the opcode and its operands *)
  match opcode, args with
  
  (* Example 1: Data Movement *)
  | Movq, [src; dest] ->
      let src_val = interp m src in
      write_op m dest src_val

  (* Example 2: Arithmetic (requires reading dest, calculating, writing back) *)
  | Addq, [src; dest] ->
      let src_val = interp m src in
      let dest_val = interp m dest in
      let result = Int64.add dest_val src_val in
      
      (* Write the result back to the destination *)
      write_op m dest result;
      
      (* 4. UPDATE FLAGS: Addq modifies condition codes *)
      (* You will need to write flag-setting logic based on x86lite semantics *)
      if result = 0L then m.flags.fz <- true else m.flags.fz <- false;
      (* ... set fs (sign) and fo (overflow) appropriately ... *)

  (* Example 3: Control Flow (manipulates %rip directly) *)
  | Subq, [src; dest] ->
      let src_val = interp m src in
      let dest_val = interp m dest in
      let result = Int64.sub dest_val src_val in
      write_op m dest result;
      m.flags.fz <- (result = 0L);
      m.flags.fs <- (result < 0L)
      (* Note: Overflow (fo) for subtraction happens when the signs of 
         the operands differ and the result sign matches the source sign *)

  | Andq, [src; dest] ->
      let src_val = interp m src in
      let dest_val = interp m dest in
      let result = Int64.logand dest_val src_val in
      write_op m dest result;
      m.flags.fz <- (result = 0L);
      m.flags.fs <- (result < 0L);
      m.flags.fo <- false (* AND always clears the overflow flag in x86 *)

  | Negq, [dest] ->
      let dest_val = interp m dest in
      let result = Int64.neg dest_val in
      write_op m dest result;
      m.flags.fz <- (result = 0L);
      m.flags.fs <- (result < 0L)

  | Shlq, [amt; dest] ->
      (* Shift amount must be cast to a standard int for OCaml's shift function *)
      let amt_val = Int64.to_int (interp m amt) in
      let dest_val = interp m dest in
      let result = Int64.shift_left dest_val amt_val in
      write_op m dest result;
      m.flags.fz <- (result = 0L);
      m.flags.fs <- (result < 0L)

  | Imulq, [src; dest] ->
      let src_val = interp m src in
      let dest_val = interp m dest in
      let result = Int64.mul dest_val src_val in
      write_op m dest result;
      m.flags.fz <- (result = 0L);
      m.flags.fs <- (result < 0L)

  (* --------------------------------------------------------- *)
  (* 2. STACK OPERATIONS                                       *)
  (* --------------------------------------------------------- *)

  | Pushq, [src] ->
      let src_val = interp m src in
      (* 1. Subtract 8 from the stack pointer *)
      let current_rsp = m.regs.(rind Rsp) in
      let new_rsp = Int64.sub current_rsp 8L in
      m.regs.(rind Rsp) <- new_rsp;
      (* 2. Write the value to the new memory address *)
      write_mem m new_rsp src_val

  | Popq, [dest] ->
      (* 1. Read the value from the current stack pointer address *)
      let current_rsp = m.regs.(rind Rsp) in
      let val_from_stack = read_mem m current_rsp in
      (* 2. Write that value into the destination operand *)
      write_op m dest val_from_stack;
      (* 3. Add 8 to the stack pointer *)
      m.regs.(rind Rsp) <- Int64.add current_rsp 8L

  (* --------------------------------------------------------- *)
  (* 3. COMPARISONS                                            *)
  (* --------------------------------------------------------- *)

  | Cmpq, [src; dest] ->
      let src_val = interp m src in
      let dest_val = interp m dest in
      let result = Int64.sub dest_val src_val in
      (* CRITICAL: Do NOT write_op the result back for Cmpq! *)
      
      (* Just set the flags so subsequent jumps know what to do *)
      m.flags.fz <- (result = 0L);
      m.flags.fs <- (result < 0L)
      
  | Jmp, [src] ->
      let target_addr = interp m src in
      m.regs.(rind Rip) <- target_addr

  (* Catch-all for unimplemented instructions *)
  | _ -> 
      failwith "Instruction semantics not yet implemented"

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
failwith "assemble unimplemented"

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
failwith "load unimplemented"

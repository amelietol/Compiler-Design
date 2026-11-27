; generated from: ./sharedtests/dbernhard/tests_if2.oat
target triple = "x86_64-unknown-linux"
define i64 @program(i64 %_argc6446, { i64, [0 x i8*] }* %_args6444) {
  %_argc6447 = alloca i64
  %_args6445 = alloca { i64, [0 x i8*] }*
  store i64 %_argc6446, i64* %_argc6447
  store { i64, [0 x i8*] }* %_args6444, { i64, [0 x i8*] }** %_args6445
  %_result6448 = call i64 @function(i64 0)
  %_result6449 = call i64 @function(i64 1)
  %_bop6450 = add i64 %_result6448, %_result6449
  %_result6451 = call i64 @function(i64 2)
  %_bop6452 = add i64 %_bop6450, %_result6451
  ret i64 %_bop6452
}

define i64 @function(i64 %_x6437) {
  %_x6438 = alloca i64
  store i64 %_x6437, i64* %_x6438
  %_x6439 = load i64, i64* %_x6438
  %_bop6440 = icmp eq i64 %_x6439, 0
  br i1 %_bop6440, label %_then6443, label %_else6442
_then6443:
  ret i64 1
_else6442:
  br label %_merge6441
_merge6441:
  ret i64 0
}


declare i64* @oat_malloc(i64)
declare i64* @oat_alloc_array(i64)
declare void @oat_assert_not_null(i8*)
declare void @oat_assert_array_length(i64*, i64)
declare { i64, [0 x i64] }* @array_of_string(i8*)
declare i8* @string_of_array({ i64, [0 x i64] }*)
declare i64 @length_of_string(i8*)
declare i8* @string_of_int(i64)
declare i8* @string_cat(i8*, i8*)
declare void @print_string(i8*)
declare void @print_int(i64)
declare void @print_bool(i1)

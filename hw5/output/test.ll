; generated from: oatprograms/run42.oat
target triple = "x86_64-unknown-linux"
define i64 @program(i64 %_argc1045, { i64, [0 x i8*] }* %_argv1043) {
  %_argc1046 = alloca i64
  %_argv1044 = alloca { i64, [0 x i8*] }*
  %_init_arr1049 = alloca { i64, [0 x { i64, [0 x i64] }*] }*
  %_i1050 = alloca i64
  %_init_arr1065 = alloca { i64, [0 x i64] }*
  %_j1066 = alloca i64
  %_a11083 = alloca { i64, [0 x { i64, [0 x i64] }*] }*
  %_init_arr1086 = alloca { i64, [0 x { i64, [0 x i64] }*] }*
  %_i1087 = alloca i64
  %_init_arr1102 = alloca { i64, [0 x i64] }*
  %_j1103 = alloca i64
  %_a21120 = alloca { i64, [0 x { i64, [0 x i64] }*] }*
  %_init_arr1123 = alloca { i64, [0 x { i64, [0 x i64] }*] }*
  %_i1124 = alloca i64
  %_init_arr1139 = alloca { i64, [0 x i64] }*
  %_j1140 = alloca i64
  %_a31157 = alloca { i64, [0 x { i64, [0 x i64] }*] }*
  %_init_arr1160 = alloca { i64, [0 x { i64, [0 x i64] }*] }*
  %_i1161 = alloca i64
  %_init_arr1176 = alloca { i64, [0 x i64] }*
  %_j1177 = alloca i64
  %_a41194 = alloca { i64, [0 x { i64, [0 x i64] }*] }*
  %_init_arr1197 = alloca { i64, [0 x i64] }*
  %_i1198 = alloca i64
  %_a51214 = alloca { i64, [0 x i64] }*
  store i64 %_argc1045, i64* %_argc1046
  store { i64, [0 x i8*] }* %_argv1043, { i64, [0 x i8*] }** %_argv1044
  %_raw_array1047 = call i64* @oat_alloc_array(i64 3)
  %_array1048 = bitcast i64* %_raw_array1047 to { i64, [0 x { i64, [0 x i64] }*] }*
  store { i64, [0 x { i64, [0 x i64] }*] }* %_array1048, { i64, [0 x { i64, [0 x i64] }*] }** %_init_arr1049
  store i64 0, i64* %_i1050
  br label %_cond1058
_cond1058:
  %_i1051 = load i64, i64* %_i1050
  %__init_arr10491052 = load { i64, [0 x { i64, [0 x i64] }*] }*, { i64, [0 x { i64, [0 x i64] }*] }** %_init_arr1049
  %_len_ptr1054 = getelementptr { i64, [0 x { i64, [0 x i64] }*] }, { i64, [0 x { i64, [0 x i64] }*] }* %__init_arr10491052, i32 0, i32 0
  %_len1053 = load i64, i64* %_len_ptr1054
  %_bop1055 = icmp slt i64 %_i1051, %_len1053
  br i1 %_bop1055, label %_body1057, label %_post1056
_body1057:
  %__init_arr10491059 = load { i64, [0 x { i64, [0 x i64] }*] }*, { i64, [0 x { i64, [0 x i64] }*] }** %_init_arr1049
  %_i1060 = load i64, i64* %_i1050
  %_tmp1061 = bitcast { i64, [0 x { i64, [0 x i64] }*] }* %__init_arr10491059 to i64*
  call void @oat_assert_array_length(i64* %_tmp1061, i64 %_i1060)
  %_index_ptr1062 = getelementptr { i64, [0 x { i64, [0 x i64] }*] }, { i64, [0 x { i64, [0 x i64] }*] }* %__init_arr10491059, i32 0, i32 1, i64 %_i1060
  %_raw_array1063 = call i64* @oat_alloc_array(i64 1)
  %_array1064 = bitcast i64* %_raw_array1063 to { i64, [0 x i64] }*
  store { i64, [0 x i64] }* %_array1064, { i64, [0 x i64] }** %_init_arr1065
  store i64 0, i64* %_j1066
  br label %_cond1074
_cond1074:
  %_j1067 = load i64, i64* %_j1066
  %__init_arr10651068 = load { i64, [0 x i64] }*, { i64, [0 x i64] }** %_init_arr1065
  %_len_ptr1070 = getelementptr { i64, [0 x i64] }, { i64, [0 x i64] }* %__init_arr10651068, i32 0, i32 0
  %_len1069 = load i64, i64* %_len_ptr1070
  %_bop1071 = icmp slt i64 %_j1067, %_len1069
  br i1 %_bop1071, label %_body1073, label %_post1072
_body1073:
  %__init_arr10651075 = load { i64, [0 x i64] }*, { i64, [0 x i64] }** %_init_arr1065
  %_j1076 = load i64, i64* %_j1066
  %_tmp1077 = bitcast { i64, [0 x i64] }* %__init_arr10651075 to i64*
  call void @oat_assert_array_length(i64* %_tmp1077, i64 %_j1076)
  %_index_ptr1078 = getelementptr { i64, [0 x i64] }, { i64, [0 x i64] }* %__init_arr10651075, i32 0, i32 1, i64 %_j1076
  store i64 0, i64* %_index_ptr1078
  %_j1079 = load i64, i64* %_j1066
  %_bop1080 = add i64 %_j1079, 1
  store i64 %_bop1080, i64* %_j1066
  br label %_cond1074
_post1072:
  store { i64, [0 x i64] }* %_array1064, { i64, [0 x i64] }** %_index_ptr1062
  %_i1081 = load i64, i64* %_i1050
  %_bop1082 = add i64 %_i1081, 1
  store i64 %_bop1082, i64* %_i1050
  br label %_cond1058
_post1056:
  store { i64, [0 x { i64, [0 x i64] }*] }* %_array1048, { i64, [0 x { i64, [0 x i64] }*] }** %_a11083
  %_raw_array1084 = call i64* @oat_alloc_array(i64 3)
  %_array1085 = bitcast i64* %_raw_array1084 to { i64, [0 x { i64, [0 x i64] }*] }*
  store { i64, [0 x { i64, [0 x i64] }*] }* %_array1085, { i64, [0 x { i64, [0 x i64] }*] }** %_init_arr1086
  store i64 0, i64* %_i1087
  br label %_cond1095
_cond1095:
  %_i1088 = load i64, i64* %_i1087
  %__init_arr10861089 = load { i64, [0 x { i64, [0 x i64] }*] }*, { i64, [0 x { i64, [0 x i64] }*] }** %_init_arr1086
  %_len_ptr1091 = getelementptr { i64, [0 x { i64, [0 x i64] }*] }, { i64, [0 x { i64, [0 x i64] }*] }* %__init_arr10861089, i32 0, i32 0
  %_len1090 = load i64, i64* %_len_ptr1091
  %_bop1092 = icmp slt i64 %_i1088, %_len1090
  br i1 %_bop1092, label %_body1094, label %_post1093
_body1094:
  %__init_arr10861096 = load { i64, [0 x { i64, [0 x i64] }*] }*, { i64, [0 x { i64, [0 x i64] }*] }** %_init_arr1086
  %_i1097 = load i64, i64* %_i1087
  %_tmp1098 = bitcast { i64, [0 x { i64, [0 x i64] }*] }* %__init_arr10861096 to i64*
  call void @oat_assert_array_length(i64* %_tmp1098, i64 %_i1097)
  %_index_ptr1099 = getelementptr { i64, [0 x { i64, [0 x i64] }*] }, { i64, [0 x { i64, [0 x i64] }*] }* %__init_arr10861096, i32 0, i32 1, i64 %_i1097
  %_raw_array1100 = call i64* @oat_alloc_array(i64 1)
  %_array1101 = bitcast i64* %_raw_array1100 to { i64, [0 x i64] }*
  store { i64, [0 x i64] }* %_array1101, { i64, [0 x i64] }** %_init_arr1102
  store i64 0, i64* %_j1103
  br label %_cond1111
_cond1111:
  %_j1104 = load i64, i64* %_j1103
  %__init_arr11021105 = load { i64, [0 x i64] }*, { i64, [0 x i64] }** %_init_arr1102
  %_len_ptr1107 = getelementptr { i64, [0 x i64] }, { i64, [0 x i64] }* %__init_arr11021105, i32 0, i32 0
  %_len1106 = load i64, i64* %_len_ptr1107
  %_bop1108 = icmp slt i64 %_j1104, %_len1106
  br i1 %_bop1108, label %_body1110, label %_post1109
_body1110:
  %__init_arr11021112 = load { i64, [0 x i64] }*, { i64, [0 x i64] }** %_init_arr1102
  %_j1113 = load i64, i64* %_j1103
  %_tmp1114 = bitcast { i64, [0 x i64] }* %__init_arr11021112 to i64*
  call void @oat_assert_array_length(i64* %_tmp1114, i64 %_j1113)
  %_index_ptr1115 = getelementptr { i64, [0 x i64] }, { i64, [0 x i64] }* %__init_arr11021112, i32 0, i32 1, i64 %_j1113
  store i64 0, i64* %_index_ptr1115
  %_j1116 = load i64, i64* %_j1103
  %_bop1117 = add i64 %_j1116, 1
  store i64 %_bop1117, i64* %_j1103
  br label %_cond1111
_post1109:
  store { i64, [0 x i64] }* %_array1101, { i64, [0 x i64] }** %_index_ptr1099
  %_i1118 = load i64, i64* %_i1087
  %_bop1119 = add i64 %_i1118, 1
  store i64 %_bop1119, i64* %_i1087
  br label %_cond1095
_post1093:
  store { i64, [0 x { i64, [0 x i64] }*] }* %_array1085, { i64, [0 x { i64, [0 x i64] }*] }** %_a21120
  %_raw_array1121 = call i64* @oat_alloc_array(i64 3)
  %_array1122 = bitcast i64* %_raw_array1121 to { i64, [0 x { i64, [0 x i64] }*] }*
  store { i64, [0 x { i64, [0 x i64] }*] }* %_array1122, { i64, [0 x { i64, [0 x i64] }*] }** %_init_arr1123
  store i64 0, i64* %_i1124
  br label %_cond1132
_cond1132:
  %_i1125 = load i64, i64* %_i1124
  %__init_arr11231126 = load { i64, [0 x { i64, [0 x i64] }*] }*, { i64, [0 x { i64, [0 x i64] }*] }** %_init_arr1123
  %_len_ptr1128 = getelementptr { i64, [0 x { i64, [0 x i64] }*] }, { i64, [0 x { i64, [0 x i64] }*] }* %__init_arr11231126, i32 0, i32 0
  %_len1127 = load i64, i64* %_len_ptr1128
  %_bop1129 = icmp slt i64 %_i1125, %_len1127
  br i1 %_bop1129, label %_body1131, label %_post1130
_body1131:
  %__init_arr11231133 = load { i64, [0 x { i64, [0 x i64] }*] }*, { i64, [0 x { i64, [0 x i64] }*] }** %_init_arr1123
  %_i1134 = load i64, i64* %_i1124
  %_tmp1135 = bitcast { i64, [0 x { i64, [0 x i64] }*] }* %__init_arr11231133 to i64*
  call void @oat_assert_array_length(i64* %_tmp1135, i64 %_i1134)
  %_index_ptr1136 = getelementptr { i64, [0 x { i64, [0 x i64] }*] }, { i64, [0 x { i64, [0 x i64] }*] }* %__init_arr11231133, i32 0, i32 1, i64 %_i1134
  %_raw_array1137 = call i64* @oat_alloc_array(i64 1)
  %_array1138 = bitcast i64* %_raw_array1137 to { i64, [0 x i64] }*
  store { i64, [0 x i64] }* %_array1138, { i64, [0 x i64] }** %_init_arr1139
  store i64 0, i64* %_j1140
  br label %_cond1148
_cond1148:
  %_j1141 = load i64, i64* %_j1140
  %__init_arr11391142 = load { i64, [0 x i64] }*, { i64, [0 x i64] }** %_init_arr1139
  %_len_ptr1144 = getelementptr { i64, [0 x i64] }, { i64, [0 x i64] }* %__init_arr11391142, i32 0, i32 0
  %_len1143 = load i64, i64* %_len_ptr1144
  %_bop1145 = icmp slt i64 %_j1141, %_len1143
  br i1 %_bop1145, label %_body1147, label %_post1146
_body1147:
  %__init_arr11391149 = load { i64, [0 x i64] }*, { i64, [0 x i64] }** %_init_arr1139
  %_j1150 = load i64, i64* %_j1140
  %_tmp1151 = bitcast { i64, [0 x i64] }* %__init_arr11391149 to i64*
  call void @oat_assert_array_length(i64* %_tmp1151, i64 %_j1150)
  %_index_ptr1152 = getelementptr { i64, [0 x i64] }, { i64, [0 x i64] }* %__init_arr11391149, i32 0, i32 1, i64 %_j1150
  store i64 0, i64* %_index_ptr1152
  %_j1153 = load i64, i64* %_j1140
  %_bop1154 = add i64 %_j1153, 1
  store i64 %_bop1154, i64* %_j1140
  br label %_cond1148
_post1146:
  store { i64, [0 x i64] }* %_array1138, { i64, [0 x i64] }** %_index_ptr1136
  %_i1155 = load i64, i64* %_i1124
  %_bop1156 = add i64 %_i1155, 1
  store i64 %_bop1156, i64* %_i1124
  br label %_cond1132
_post1130:
  store { i64, [0 x { i64, [0 x i64] }*] }* %_array1122, { i64, [0 x { i64, [0 x i64] }*] }** %_a31157
  %_raw_array1158 = call i64* @oat_alloc_array(i64 3)
  %_array1159 = bitcast i64* %_raw_array1158 to { i64, [0 x { i64, [0 x i64] }*] }*
  store { i64, [0 x { i64, [0 x i64] }*] }* %_array1159, { i64, [0 x { i64, [0 x i64] }*] }** %_init_arr1160
  store i64 0, i64* %_i1161
  br label %_cond1169
_cond1169:
  %_i1162 = load i64, i64* %_i1161
  %__init_arr11601163 = load { i64, [0 x { i64, [0 x i64] }*] }*, { i64, [0 x { i64, [0 x i64] }*] }** %_init_arr1160
  %_len_ptr1165 = getelementptr { i64, [0 x { i64, [0 x i64] }*] }, { i64, [0 x { i64, [0 x i64] }*] }* %__init_arr11601163, i32 0, i32 0
  %_len1164 = load i64, i64* %_len_ptr1165
  %_bop1166 = icmp slt i64 %_i1162, %_len1164
  br i1 %_bop1166, label %_body1168, label %_post1167
_body1168:
  %__init_arr11601170 = load { i64, [0 x { i64, [0 x i64] }*] }*, { i64, [0 x { i64, [0 x i64] }*] }** %_init_arr1160
  %_i1171 = load i64, i64* %_i1161
  %_tmp1172 = bitcast { i64, [0 x { i64, [0 x i64] }*] }* %__init_arr11601170 to i64*
  call void @oat_assert_array_length(i64* %_tmp1172, i64 %_i1171)
  %_index_ptr1173 = getelementptr { i64, [0 x { i64, [0 x i64] }*] }, { i64, [0 x { i64, [0 x i64] }*] }* %__init_arr11601170, i32 0, i32 1, i64 %_i1171
  %_raw_array1174 = call i64* @oat_alloc_array(i64 1)
  %_array1175 = bitcast i64* %_raw_array1174 to { i64, [0 x i64] }*
  store { i64, [0 x i64] }* %_array1175, { i64, [0 x i64] }** %_init_arr1176
  store i64 0, i64* %_j1177
  br label %_cond1185
_cond1185:
  %_j1178 = load i64, i64* %_j1177
  %__init_arr11761179 = load { i64, [0 x i64] }*, { i64, [0 x i64] }** %_init_arr1176
  %_len_ptr1181 = getelementptr { i64, [0 x i64] }, { i64, [0 x i64] }* %__init_arr11761179, i32 0, i32 0
  %_len1180 = load i64, i64* %_len_ptr1181
  %_bop1182 = icmp slt i64 %_j1178, %_len1180
  br i1 %_bop1182, label %_body1184, label %_post1183
_body1184:
  %__init_arr11761186 = load { i64, [0 x i64] }*, { i64, [0 x i64] }** %_init_arr1176
  %_j1187 = load i64, i64* %_j1177
  %_tmp1188 = bitcast { i64, [0 x i64] }* %__init_arr11761186 to i64*
  call void @oat_assert_array_length(i64* %_tmp1188, i64 %_j1187)
  %_index_ptr1189 = getelementptr { i64, [0 x i64] }, { i64, [0 x i64] }* %__init_arr11761186, i32 0, i32 1, i64 %_j1187
  store i64 0, i64* %_index_ptr1189
  %_j1190 = load i64, i64* %_j1177
  %_bop1191 = add i64 %_j1190, 1
  store i64 %_bop1191, i64* %_j1177
  br label %_cond1185
_post1183:
  store { i64, [0 x i64] }* %_array1175, { i64, [0 x i64] }** %_index_ptr1173
  %_i1192 = load i64, i64* %_i1161
  %_bop1193 = add i64 %_i1192, 1
  store i64 %_bop1193, i64* %_i1161
  br label %_cond1169
_post1167:
  store { i64, [0 x { i64, [0 x i64] }*] }* %_array1159, { i64, [0 x { i64, [0 x i64] }*] }** %_a41194
  %_raw_array1195 = call i64* @oat_alloc_array(i64 3)
  %_array1196 = bitcast i64* %_raw_array1195 to { i64, [0 x i64] }*
  store { i64, [0 x i64] }* %_array1196, { i64, [0 x i64] }** %_init_arr1197
  store i64 0, i64* %_i1198
  br label %_cond1206
_cond1206:
  %_i1199 = load i64, i64* %_i1198
  %__init_arr11971200 = load { i64, [0 x i64] }*, { i64, [0 x i64] }** %_init_arr1197
  %_len_ptr1202 = getelementptr { i64, [0 x i64] }, { i64, [0 x i64] }* %__init_arr11971200, i32 0, i32 0
  %_len1201 = load i64, i64* %_len_ptr1202
  %_bop1203 = icmp slt i64 %_i1199, %_len1201
  br i1 %_bop1203, label %_body1205, label %_post1204
_body1205:
  %__init_arr11971207 = load { i64, [0 x i64] }*, { i64, [0 x i64] }** %_init_arr1197
  %_i1208 = load i64, i64* %_i1198
  %_tmp1209 = bitcast { i64, [0 x i64] }* %__init_arr11971207 to i64*
  call void @oat_assert_array_length(i64* %_tmp1209, i64 %_i1208)
  %_index_ptr1210 = getelementptr { i64, [0 x i64] }, { i64, [0 x i64] }* %__init_arr11971207, i32 0, i32 1, i64 %_i1208
  %_i1211 = load i64, i64* %_i1198
  store i64 %_i1211, i64* %_index_ptr1210
  %_i1212 = load i64, i64* %_i1198
  %_bop1213 = add i64 %_i1212, 1
  store i64 %_bop1213, i64* %_i1198
  br label %_cond1206
_post1204:
  store { i64, [0 x i64] }* %_array1196, { i64, [0 x i64] }** %_a51214
  %_a21215 = load { i64, [0 x { i64, [0 x i64] }*] }*, { i64, [0 x { i64, [0 x i64] }*] }** %_a21120
  %_tmp1216 = bitcast { i64, [0 x { i64, [0 x i64] }*] }* %_a21215 to i64*
  call void @oat_assert_array_length(i64* %_tmp1216, i64 0)
  %_index_ptr1217 = getelementptr { i64, [0 x { i64, [0 x i64] }*] }, { i64, [0 x { i64, [0 x i64] }*] }* %_a21215, i32 0, i32 1, i32 0
  %_a51218 = load { i64, [0 x i64] }*, { i64, [0 x i64] }** %_a51214
  store { i64, [0 x i64] }* %_a51218, { i64, [0 x i64] }** %_index_ptr1217
  %_a21219 = load { i64, [0 x { i64, [0 x i64] }*] }*, { i64, [0 x { i64, [0 x i64] }*] }** %_a21120
  %_tmp1220 = bitcast { i64, [0 x { i64, [0 x i64] }*] }* %_a21219 to i64*
  call void @oat_assert_array_length(i64* %_tmp1220, i64 0)
  %_index_ptr1221 = getelementptr { i64, [0 x { i64, [0 x i64] }*] }, { i64, [0 x { i64, [0 x i64] }*] }* %_a21219, i32 0, i32 1, i32 0
  %_index1222 = load { i64, [0 x i64] }*, { i64, [0 x i64] }** %_index_ptr1221
  %_tmp1223 = bitcast { i64, [0 x i64] }* %_index1222 to i64*
  call void @oat_assert_array_length(i64* %_tmp1223, i64 0)
  %_index_ptr1224 = getelementptr { i64, [0 x i64] }, { i64, [0 x i64] }* %_index1222, i32 0, i32 1, i32 0
  store i64 2, i64* %_index_ptr1224
  %_a21225 = load { i64, [0 x { i64, [0 x i64] }*] }*, { i64, [0 x { i64, [0 x i64] }*] }** %_a21120
  store { i64, [0 x { i64, [0 x i64] }*] }* %_a21225, { i64, [0 x { i64, [0 x i64] }*] }** %_a11083
  %_a11226 = load { i64, [0 x { i64, [0 x i64] }*] }*, { i64, [0 x { i64, [0 x i64] }*] }** %_a11083
  store { i64, [0 x { i64, [0 x i64] }*] }* %_a11226, { i64, [0 x { i64, [0 x i64] }*] }** %_a31157
  %_a41227 = load { i64, [0 x { i64, [0 x i64] }*] }*, { i64, [0 x { i64, [0 x i64] }*] }** %_a41194
  store { i64, [0 x { i64, [0 x i64] }*] }* %_a41227, { i64, [0 x { i64, [0 x i64] }*] }** %_a11083
  %_a31228 = load { i64, [0 x { i64, [0 x i64] }*] }*, { i64, [0 x { i64, [0 x i64] }*] }** %_a31157
  store { i64, [0 x { i64, [0 x i64] }*] }* %_a31228, { i64, [0 x { i64, [0 x i64] }*] }** %_a21120
  %_a21229 = load { i64, [0 x { i64, [0 x i64] }*] }*, { i64, [0 x { i64, [0 x i64] }*] }** %_a21120
  store { i64, [0 x { i64, [0 x i64] }*] }* %_a21229, { i64, [0 x { i64, [0 x i64] }*] }** %_a41194
  %_a41230 = load { i64, [0 x { i64, [0 x i64] }*] }*, { i64, [0 x { i64, [0 x i64] }*] }** %_a41194
  store { i64, [0 x { i64, [0 x i64] }*] }* %_a41230, { i64, [0 x { i64, [0 x i64] }*] }** %_a31157
  %_a31231 = load { i64, [0 x { i64, [0 x i64] }*] }*, { i64, [0 x { i64, [0 x i64] }*] }** %_a31157
  %_tmp1232 = bitcast { i64, [0 x { i64, [0 x i64] }*] }* %_a31231 to i64*
  call void @oat_assert_array_length(i64* %_tmp1232, i64 0)
  %_index_ptr1233 = getelementptr { i64, [0 x { i64, [0 x i64] }*] }, { i64, [0 x { i64, [0 x i64] }*] }* %_a31231, i32 0, i32 1, i32 0
  %_index1234 = load { i64, [0 x i64] }*, { i64, [0 x i64] }** %_index_ptr1233
  %_tmp1235 = bitcast { i64, [0 x i64] }* %_index1234 to i64*
  call void @oat_assert_array_length(i64* %_tmp1235, i64 0)
  %_index_ptr1236 = getelementptr { i64, [0 x i64] }, { i64, [0 x i64] }* %_index1234, i32 0, i32 1, i32 0
  %_index1237 = load i64, i64* %_index_ptr1236
  ret i64 %_index1237
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

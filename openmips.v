`include "defines.v"

module openmips(
    input wire         clk,
    input  wire         rst,

    input wire[`RegBus]        rom_data_i, // 从指令存储器取得的指令
    output wire[`RegBus]       rom_addr_o, // 输出奥指令存储器的地址
    output wire                rom_ce_o // 使能信号
);

    // 连接IF/ID模块与译码阶段ID模块的变量
    wire[`InstAddrBus] pc;
    wire[`InstAddrBus] id_pc_i;
    wire[`InstBus]     id_inst_i;

    // 连接译码阶段ID模块输出与ID/EX模块的输入的变量
    wire[`AluOpBus]    id_aluop_o;
    wire[`AluSelBus]   id_alusel_o;
    wire[`RegBus]      id_reg1_o;
    wire[`RegBus]      id_reg2_o;
    wire               id_wreg_o;
    wire[`RegAddrBus]  id_wd_o;
 
    // 连接ID/EX模块输出与执行阶段EX模块的输入的变量
    wire[`AluOpBus]    ex_aluop_i;
    wire[`AluSelBus]   ex_alusel_i;
    wire[`RegBus]      ex_reg1_i;
    wire[`RegBus]      ex_reg2_i;
    wire               ex_wreg_i;
    wire[`RegAddrBus]  ex_wd_i;
    
    // 连接执行阶段EX模块的输出与EX/MEM模块的输入的变量
      // 连接执行阶段EX模块的输出与EX/MEM模块的输入的变量
    wire               ex_wreg_o;
    wire[`RegAddrBus]  ex_wd_o;
    wire[`RegBus]      ex_wdata_o;

    // 连接EX/MEM模块的输出与访存阶段MEM模块的输入的变量
    wire               mem_wreg_i;
    wire[`RegAddrBus]  mem_wd_i;
    wire[`RegBus]      mem_wdata_i;

    // 连接访存阶段MEM模块的输出与MEM/WB模块的输入的变量
    wire               mem_wreg_o;
    wire[`RegAddrBus]  mem_wd_o;
    wire[`RegBus]      mem_wdata_o;
        
    // 连接MEM/WB模块的输出与回写阶段的输入的变量       
    wire               wb_wreg_i;
    wire[`RegAddrBus]  wb_wd_i;
    wire[`RegBus]      wb_wdata_i;
    
    // 连接译码阶段ID模块与通用寄存器Regfile模块的变量
    wire               reg1_read;
    wire               reg2_read;
    wire[`RegBus]      reg1_data;
    wire[`RegBus]      reg2_data;
    wire[`RegAddrBus]  reg1_addr;
    wire[`RegAddrBus]  reg2_addr;

    wire[`RegBus] 	hi;
    wire[`RegBus]   lo;
        
    /**
     * @name pc_reg实例化，取址阶段
     * @input rst 复位信号
     * @input clk 时钟信号
     * @output pc 指令地址
     * @output rom_ce_o 存储器使能信号
     */
    pc_reg pc_reg0(
        .clk(clk),
        .rst(rst),
        .pc(pc),
        .ce(rom_ce_o)
    );
 
    assign rom_addr_o = pc;   // 指令存储器的输入地址就是pc的值

    /**
     * @name IF/ID模块例化
     * @input rst 复位信号
     * @input clk 时钟信号
     * @input if_pc 取指阶段得到的指令地址
     * @input if_inst 取值阶段得到的指令
     * @output id_pc 译码阶段需要的pc地址
     * @output id_inst 译码阶段需要的指令
     */
    if_id if_id0(
        .rst(rst),
        .clk(clk),
        .if_pc(pc),
        .if_inst(rom_data_i),
        .id_pc(id_pc_i),
        .id_inst(id_inst_i)
    );

    /**
     * @name 译码阶段
     * @input rst 复位信号
     * @input pc_i 取值阶段得到的地址
     * @input inst_i 取值阶段得到的指令
     * @input reg1_data_i 读寄存器1的数据
     * @input reg2_data_i 读寄存器2的数据  regfile读是组合电路

     *      执行阶段数据前推
     * @input ex_wreg_i 执行阶段写使能
     * @input ex_wdata_i 执行阶段写入的数据
     * @input ex_wd_i 执行阶段写入寄存器地址

     *      访存阶段数据前推
     * @input mem_wreg_i 访存阶段写使能
     * @input mem_wdata_i 访存阶段写入的数据
     * @input mem_wd_i 访存阶段写入寄存器地址

     * @input reg1_read_o 读寄存器1使能
     * @input reg2_read_o 读寄存器2使能

     * @input reg1_addr_o 读寄存器1地址
     * @input reg2_addr_o 读寄存器2地址

     * @output aluop_o 运算子类型 是or and 类型
     * @output alusel_o 运算类型 是要写入寄存器
     * @output reg1_o 寄存器1数据
     * @output reg2_o 寄存器2数据
     * @output wd_o 写地址
     * @output wreg_o 写使能
     */
    id id0(
        .rst(rst),
        .pc_i(id_pc_i),
        .inst_i(id_inst_i),

        // 来自Regfile模块的输入
        .reg1_data_i(reg1_data),
        .reg2_data_i(reg2_data),

        .ex_wreg_i(ex_wreg_o),
        .ex_wdata_i(ex_wdata_o),
        .ex_wd_i(ex_wd_o),

        .mem_wreg_i(mem_wreg_o),
        .mem_wdata_i(mem_wdata_o),
        .mem_wd_i(mem_wd_o),
        // 送到regfile模块的信息
        .reg1_read_o(reg1_read),
        .reg2_read_o(reg2_read),
        .reg1_addr_o(reg1_addr),
        .reg2_addr_o(reg2_addr),

        // 送到ID/EX模块的信息
        .aluop_o(id_aluop_o),
        .alusel_o(id_alusel_o),
        .reg1_o(id_reg1_o),
        .reg2_o(id_reg2_o),
        .wd_o(id_wd_o),
        .wreg_o(id_wreg_o)
    );
    
    
    /**
     * @name 通用寄存器Regfile模块例化
     * @input rst 复位信号
     * @input clk 时钟信号
     * @input we 写使能
     * @input waddr 要写入寄存器的地址
     * @input wdata 要写入寄存器的数据
     * @input re1 第一个读寄存器使能
     * @input raddr1 第一个读寄存器地址
     * @input re2 第二个读寄存器使能
     * @input raddr2 第二个读寄存器地址
     * @output rdata1 第一个读寄存器数据
     * @output rdata2 第二个读寄存器数据
     */
    regfile regfile1(
        .rst(rst),
        .clk (clk),
        .we(wb_wreg_i),
        .waddr(wb_wd_i),
        .wdata(wb_wdata_i),
        .re1(reg1_read),
        .raddr1(reg1_addr),
        .re2(reg2_read),
        .raddr2(reg2_addr),
        .rdata1(reg1_data),
        .rdata2(reg2_data)
    );
    
    // ID/EX模块例化
    id_ex id_ex0(
        .clk(clk),
        .rst(rst),

        // 从译码阶段ID模块传递过来的信息
        .id_aluop(id_aluop_o),
        .id_alusel(id_alusel_o),
        .id_reg1(id_reg1_o),
        .id_reg2(id_reg2_o),
        .id_wd(id_wd_o),
        .id_wreg(id_wreg_o),

        // 传递到执行阶段EX模块的信息
        .ex_aluop(ex_aluop_i),
        .ex_alusel(ex_alusel_i),
        .ex_reg1(ex_reg1_i),
        .ex_reg2(ex_reg2_i),
        .ex_wd(ex_wd_i),
        .ex_wreg(ex_wreg_i)
    );
 
       // EX模块例化
    ex ex0(
        .rst(rst),

        // 从ID/EX模块传递过来的的信息
        .aluop_i(ex_aluop_i),
        .alusel_i(ex_alusel_i),
        .reg1_i(ex_reg1_i),
        .reg2_i(ex_reg2_i),
        .wd_i(ex_wd_i),
        .wreg_i(ex_wreg_i),
        .hi_i(hi),
		.lo_i(lo),

        .wb_hi_i(wb_hi_i),
        .wb_lo_i(wb_lo_i),
        .wb_whilo_i(wb_whilo_i),
        .mem_hi_i(mem_hi_o),
        .mem_lo_i(mem_lo_o),
        .mem_whilo_i(mem_whilo_o),

        //输出到EX/MEM模块的信息
        .wd_o(ex_wd_o),
        .wreg_o(ex_wreg_o),
        .wdata_o(ex_wdata_o),
        .hi_o(ex_hi_o),
		.lo_o(ex_lo_o),
		.whilo_o(ex_whilo_o)
    );
    
       // EX/MEM模块例化
    ex_mem ex_mem0(
        .clk(clk),
        .rst(rst),
        
        // 来自执行阶段EX模块的信息
        .ex_wd(ex_wd_o),
        .ex_wreg(ex_wreg_o),
        .ex_wdata(ex_wdata_o),

        .ex_hi(ex_hi_o),
		.ex_lo(ex_lo_o),
		.ex_whilo(ex_whilo_o),

        // 送到访存阶段MEM模块的信息
        .mem_wd(mem_wd_i),
        .mem_wreg(mem_wreg_i),
        .mem_wdata(mem_wdata_i),
        .mem_hi(mem_hi_i),
		.mem_lo(mem_lo_i),
		.mem_whilo(mem_whilo_i)
    );
    
    // MEM模块例化
    mem mem0(
        .rst(rst),
       
        // 来自EX/MEM模块的信息 
        .wd_i(mem_wd_i),
        .wreg_i(mem_wreg_i),
        .wdata_i(mem_wdata_i),
        .hi_i(mem_hi_i),
		.lo_i(mem_lo_i),
		.whilo_i(mem_whilo_i),

        // 送到MEM/WB模块的信息
        .wd_o(mem_wd_o),
        .wreg_o(mem_wreg_o),
        .wdata_o(mem_wdata_o),
        .hi_o(mem_hi_o),
		.lo_o(mem_lo_o),
		.whilo_o(mem_whilo_o)
    );
    
       // MEM/WB模块例化
    mem_wb mem_wb0(
        .clk(clk),
        .rst(rst),
        // 来自访存阶段MEM模块的信息 
        .mem_wd(mem_wd_o),
        .mem_wreg(mem_wreg_o),
        .mem_wdata(mem_wdata_o),
        .mem_hi(mem_hi_o),
		.mem_lo(mem_lo_o),
		.mem_whilo(mem_whilo_o),

        // 送到回写阶段的信息
        .wb_wd(wb_wd_i),
        .wb_wreg(wb_wreg_i),
        .wb_wdata(wb_wdata_i),
        .wb_hi(wb_hi_i),
		.wb_lo(wb_lo_i),
		.wb_whilo(wb_whilo_i)
    );

    hilo_reg hilo_reg0(
		.clk(clk),
		.rst(rst),
	
		.we(wb_whilo_i),
		.hi_i(wb_hi_i),
		.lo_i(wb_lo_i),
	

		.hi_o(hi),
		.lo_o(lo)
	);
    
endmodule
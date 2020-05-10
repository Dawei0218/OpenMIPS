`include "defines.v"
module id(
    input wire rst,
    input wire[`InstAddrBus] pc_i,
    input wire[`InstBus] inst_i,

    input wire[`RegBus] reg1_data_i,
    input wire[`RegBus] reg2_data_i,

  //处于执行阶段的指令的运算结果 
    input wire ex_wreg_i,
    input wire[`RegBus] ex_wdata_i,
    input wire[`RegAddrBus] ex_wd_i,
     
    //处于访存阶段的指令的运算结果 
    input wire mem_wreg_i,
    input wire[`RegBus] mem_wdata_i,
    input wire[`RegAddrBus] mem_wd_i,

    // 如果上一条指令是转移指令，那么下一条指令进入译码阶段的时候，输入变量 
    // is_in_delayslot_i为true，表示是延迟槽指令，反之，为false 
    input wire is_in_delayslot_i,
    // 下一条译码的指令是否位于延迟槽
    output reg next_inst_in_delayslot_o,
    // 是否发送转移
    output reg branch_flag_o,
    // 转移到目标地址
    output reg[`RegBus] branch_target_address_o,
    // 转移指令要保存的返回地址
    output reg[`RegBus] link_addr_o,
    // 当前译码指令是否位于延迟槽
    output reg is_in_delayslot_o,

    output reg reg1_read_o,
    output reg reg2_read_o,
    output reg[`RegAddrBus] reg1_addr_o,
    output reg[`RegAddrBus] reg2_addr_o,

    output reg[`AluOpBus] aluop_o,
    output reg[`AluSelBus] alusel_o,
    output reg[`RegBus] reg1_o,
    output reg[`RegBus] reg2_o,
    output reg[`RegAddrBus] wd_o,
    output reg wreg_o,
    output wire stallreq
);

assign stallreq = `NoStop;

// 取出指令码，功能码，高6位是指令码

wire[5:0] op = inst_i[31:26];
wire[4:0] op2 = inst_i[10:6];
wire[5:0] op3 = inst_i[5:0];
wire[4:0] op4 = inst_i[20:16];
// 保存立即数
reg[`RegBus] imm;
// 指令是否有效
reg instvalid;


wire[`RegBus] pc_plus_8;
wire[`RegBus] pc_plus_4;

wire[`RegBus] imm_sll2_signedext; 

assign pc_plus_8 = pc_i + 8;    //保存当前译码阶段指令后面第2条指令的地址 
assign pc_plus_4 = pc_i + 4;

// imm_sll2_signedext对应分支指令中的offset左移两位，再符号扩展至32位的值 
assign imm_sll2_signedext = {{14{inst_i[15]}}, inst_i[15:0], 2'b00 };  

always @ (*) 
begin 
    if (rst == `RstEnable)
        begin
            aluop_o <= `EXE_NOP_OP;
            alusel_o <= `EXE_RES_NOP;
            wd_o <= `NOPRegAddr;
            wreg_o <= `WriteDisable;
            instvalid <= `InstValid;
            reg1_read_o <= 1'b0;
            reg2_read_o <= 1'b0;
            reg1_addr_o <= `NOPRegAddr;
            reg2_addr_o <= `NOPRegAddr;
            imm <= 32'h0;
            link_addr_o <= `ZeroWord; 
            branch_target_address_o <= `ZeroWord; 
            branch_flag_o <= `NotBranch; 
            next_inst_in_delayslot_o <= `NotInDelaySlot; 
        end
    else
        begin
            aluop_o     <= `EXE_NOP_OP;
            alusel_o    <= `EXE_RES_NOP;
            wd_o        <= inst_i[15:11];
            wreg_o      <= `WriteDisable;
            instvalid   <= `InstInvalid;    
            reg1_read_o <= 1'b0;
            reg2_read_o <= 1'b0;
            reg1_addr_o <= inst_i[25:21];   // 默认通过Regfile读端口1读取的寄存器地址
            reg2_addr_o <= inst_i[20:16];   // 默认通过Regfile读端口2读取的寄存器地址
            imm <= `ZeroWord;
            link_addr_o <= `ZeroWord; 
            branch_target_address_o <= `ZeroWord; 
            branch_flag_o <= `NotBranch; 
            next_inst_in_delayslot_o <= `NotInDelaySlot; 

            case (op)
                `EXE_SPECIAL_INST:
                    begin

                        case (op2)
                            5'b00000:
                                begin

		    			            case (op3)
                                        `EXE_JR:
                                            begin // jr指令 
                                                wreg_o <= `WriteDisable;
                                                aluop_o <= `EXE_JR_OP;
                                                alusel_o <= `EXE_RES_JUMP_BRANCH;
                                                reg1_read_o <= 1'b1;
                                                reg2_read_o <= 1'b0;
                                                link_addr_o <= `ZeroWord;
                                                branch_target_address_o <= reg1_o;
                                                branch_flag_o <= `Branch;
                                                next_inst_in_delayslot_o <= `InDelaySlot;
                                                instvalid <= `InstValid;
                                            end
                                        `EXE_JALR:
                                            begin // jalr指令 
                                                wreg_o <= `WriteEnable;
                                                aluop_o <= `EXE_JALR_OP;
                                                alusel_o <= `EXE_RES_JUMP_BRANCH;
                                                reg1_read_o <= 1'b1;
                                                reg2_read_o <= 1'b0;
                                                wd_o <= inst_i[15:11];
                                                link_addr_o <= pc_plus_8;
                                                branch_target_address_o <= reg1_o;
                                                branch_flag_o <= `Branch;
                                                next_inst_in_delayslot_o <= `InDelaySlot;
                                                instvalid <= `InstValid;
                                            end 
                                        `EXE_OR:
                                            begin
		    					                wreg_o <= `WriteEnable;
                                                aluop_o <= `EXE_OR_OP;
		  						                alusel_o <= `EXE_RES_LOGIC;
                                                reg1_read_o <= 1'b1;
                                                reg2_read_o <= 1'b1;
		  						                instvalid <= `InstValid;
								            end
		    				            `EXE_AND:
                                            begin
		    					                wreg_o <= `WriteEnable;
                                                aluop_o <= `EXE_AND_OP;
		  						                alusel_o <= `EXE_RES_LOGIC;
                                                reg1_read_o <= 1'b1;
                                                reg2_read_o <= 1'b1;
		  						                instvalid <= `InstValid;
								            end
		    				            `EXE_XOR:
                                            begin
		    					                wreg_o <= `WriteEnable;
                                                aluop_o <= `EXE_XOR_OP;
		  						                alusel_o <= `EXE_RES_LOGIC;
                                                reg1_read_o <= 1'b1;
                                                reg2_read_o <= 1'b1;
		  						                instvalid <= `InstValid;
								            end
		    				            `EXE_NOR:
                                            begin
		    					                wreg_o <= `WriteEnable;
                                                aluop_o <= `EXE_NOR_OP;
		  						                alusel_o <= `EXE_RES_LOGIC;
                                                reg1_read_o <= 1'b1;
                                                reg2_read_o <= 1'b1;
		  						                instvalid <= `InstValid;
								            end 
								        `EXE_SLLV:
                                            begin
									            wreg_o <= `WriteEnable;
                                                aluop_o <= `EXE_SLL_OP;
		  						                alusel_o <= `EXE_RES_SHIFT;
                                                reg1_read_o <= 1'b1;
                                                reg2_read_o <= 1'b1;
		  						                instvalid <= `InstValid;
								            end 
								        `EXE_SRLV:
                                            begin
									            wreg_o <= `WriteEnable;
                                                aluop_o <= `EXE_SRL_OP;
		  						                alusel_o <= `EXE_RES_SHIFT;
                                                reg1_read_o <= 1'b1;
                                                reg2_read_o <= 1'b1;
		  						                instvalid <= `InstValid;
								            end
								        `EXE_SRAV:
                                            begin
									            wreg_o <= `WriteEnable;
                                                aluop_o <= `EXE_SRA_OP;
		  						                alusel_o <= `EXE_RES_SHIFT;
                                                reg1_read_o <= 1'b1;
                                                reg2_read_o <= 1'b1;
		  						                instvalid <= `InstValid;
		  						            end
								        `EXE_SYNC:
                                            begin
									            wreg_o <= `WriteDisable;
                                                aluop_o <= `EXE_NOP_OP;
		  						                alusel_o <= `EXE_RES_NOP;
                                                reg1_read_o <= 1'b0;
                                                reg2_read_o <= 1'b1;
		  						                instvalid <= `InstValid;
								            end
                                        `EXE_MFHI:
                                            begin                  // mfhi指令
                                                wreg_o <= `WriteEnable;
                                                aluop_o <= `EXE_MFHI_OP;
                                                alusel_o <= `EXE_RES_MOVE;
                                                reg1_read_o <= 1'b0;
                                                reg2_read_o <= 1'b0;
                                                instvalid   <= `InstValid;
                                            end
                                        `EXE_MFLO:
                                            begin                  // mflo指令 
                                                wreg_o      <= `WriteEnable;
                                                aluop_o     <= `EXE_MFLO_OP;
                                                alusel_o    <= `EXE_RES_MOVE;
                                                reg1_read_o <= 1'b0;
                                                reg2_read_o <= 1'b0;
                                                instvalid   <= `InstValid;
                                            end
                                        `EXE_MTHI:
                                            begin                  // mthi指令
                                                wreg_o      <= `WriteDisable;  
                                                aluop_o     <= `EXE_MTHI_OP; 
                                                reg1_read_o <= 1'b1; 
                                                reg2_read_o <= 1'b0;  
                                                instvalid   <= `InstValid;  
                                            end 
                                        `EXE_MTLO:
                                            begin                  // mtlo指令 
                                                wreg_o      <= `WriteDisable;
                                                aluop_o     <= `EXE_MTLO_OP;
                                                reg1_read_o <= 1'b1;
                                                reg2_read_o <= 1'b0;
                                                instvalid   <= `InstValid;
                                            end 
                                        `EXE_MOVN:
                                            begin                  // movn指令 
                                                aluop_o     <= `EXE_MOVN_OP; 
                                                alusel_o    <= `EXE_RES_MOVE;  
                                                reg1_read_o <= 1'b1; 
                                                reg2_read_o <= 1'b1; 
                                                instvalid   <= `InstValid; 
                                                //reg2_o的值就是地址为rt的通用寄存器的值 
                                                if(reg2_o != `ZeroWord)
                                                    begin    
                                                        wreg_o <= `WriteEnable; 
                                                    end
                                                else
                                                    begin 
                                                        wreg_o <= `WriteDisable; 
                                                    end 
                                            end 
                                        `EXE_MOVZ:
                                            begin                  // movz指令 
                                                aluop_o     <= `EXE_MOVZ_OP; 
                                                alusel_o    <= `EXE_RES_MOVE;  
                                                reg1_read_o <= 1'b1;  
                                                reg2_read_o <= 1'b1; 
                                                instvalid   <= `InstValid; 
                                                //reg2_o的值就是地址为rt的通用寄存器的值 
                                                if(reg2_o == `ZeroWord)
                                                    begin 
                                                        wreg_o <= `WriteEnable; 
                                                    end
                                                else
                                                    begin 
                                                        wreg_o <= `WriteDisable; 
                                                    end
                                            end
                                        `EXE_SLT:
                                            begin        // slt指令 
                                                wreg_o      <= `WriteEnable; 
                                                aluop_o     <= `EXE_SLT_OP; 
                                                alusel_o    <= `EXE_RES_ARITHMETIC; 
                                                reg1_read_o <= 1'b1; 
                                                reg2_read_o <= 1'b1; 
                                                instvalid   <= `InstValid; 
                                            end
                                        `EXE_SLTU:
                                            begin                    // sltu指令 
                                                wreg_o      <= `WriteEnable; 
                                                aluop_o     <= `EXE_SLTU_OP; 
                                                alusel_o    <= `EXE_RES_ARITHMETIC; 
                                                reg1_read_o <= 1'b1; 
                                                reg2_read_o <= 1'b1; 
                                                instvalid   <= `InstValid; 
                                            end
                                        `EXE_ADD:
                                            begin                     // add指令 
                                                wreg_o      <= `WriteEnable; 
                                                aluop_o     <= `EXE_ADD_OP; 
                                                alusel_o    <= `EXE_RES_ARITHMETIC; 
                                                reg1_read_o <= 1'b1; 
                                                reg2_read_o <= 1'b1; 
                                                instvalid   <= `InstValid; 
                                            end 
                                        `EXE_ADDU:
                                            begin                  // addu指令 
                                                wreg_o      <= `WriteEnable; 
                                                aluop_o     <= `EXE_ADDU_OP; 
                                                alusel_o    <= `EXE_RES_ARITHMETIC; 
                                                reg1_read_o <= 1'b1; 
                                                reg2_read_o <= 1'b1; 
                                                instvalid   <= `InstValid; 
                                            end 
                                        `EXE_SUB:
                                            begin                   // sub指令
                                                wreg_o      <= `WriteEnable; 
                                                aluop_o     <= `EXE_SUB_OP; 
                                                alusel_o    <= `EXE_RES_ARITHMETIC; 
                                                reg1_read_o <= 1'b1; 
                                                reg2_read_o <= 1'b1; 
                                                instvalid   <= `InstValid; 
                                            end
                                        `EXE_SUBU:
                                            begin                    // subu指令 
                                                wreg_o      <= `WriteEnable; 
                                                aluop_o     <= `EXE_SUBU_OP; 
                                                alusel_o    <= `EXE_RES_ARITHMETIC; 
                                                reg1_read_o <= 1'b1; 
                                                reg2_read_o <= 1'b1; 
                                                instvalid   <= `InstValid; 
                                            end
                                        `EXE_MULT:
                                            begin                   // mult指令 
                                                wreg_o      <= `WriteDisable;
                                                wreg_o      <= `WriteDisable; 
                                                aluop_o     <= `EXE_MULT_OP; 
                                                reg1_read_o <= 1'b1; 
                                                reg2_read_o <= 1'b1;  
                                                instvalid   <= `InstValid; 
                                            end
                                        `EXE_MULTU:
                                            begin               // multu指令 
                                                wreg_o      <= `WriteDisable; 
                                                aluop_o     <= `EXE_MULTU_OP; 
                                                reg1_read_o <= 1'b1; 
                                                reg2_read_o <= 1'b1;  
                                                instvalid   <= `InstValid; 
                                            end
                                        `EXE_DIV:
                                            begin               //div指令 
                                                wreg_o      <= `WriteDisable; 
                                                aluop_o     <= `EXE_DIV_OP; 
                                                reg1_read_o <= 1'b1;
                                                reg2_read_o <= 1'b1;  
                                                instvalid   <= `InstValid; 
                                            end 
                                        `EXE_DIVU:
                                            begin              //divu指令 
                                                wreg_o      <= `WriteDisable; 
                                                aluop_o     <= `EXE_DIVU_OP; 
                                                reg1_read_o <= 1'b1; 
                                                reg2_read_o <= 1'b1;  
                                                instvalid   <= `InstValid; 
                                            end
						                default:
                                            begin
						                    end
                                    endcase
						        end
						    default:
                                begin
                                end
					    endcase
					end									  
		  	    `EXE_ORI:
                    begin                        //ORIָ��
                        wreg_o <= `WriteEnable;
                        aluop_o <= `EXE_OR_OP;
                        alusel_o <= `EXE_RES_LOGIC;
                        reg1_read_o <= 1'b1;
                        reg2_read_o <= 1'b0;
					    imm <= {16'h0, inst_i[15:0]};
                        wd_o <= inst_i[20:16];
					    instvalid <= `InstValid;
		  	        end
                `EXE_J:
                    begin // j指令 
                        wreg_o <= `WriteDisable;
                        aluop_o <= `EXE_J_OP;
                        alusel_o <= `EXE_RES_JUMP_BRANCH;
                        reg1_read_o <= 1'b0;
                        reg2_read_o <= 1'b0;
                        link_addr_o <= `ZeroWord;
                        branch_flag_o <= `Branch;
                        next_inst_in_delayslot_o <= `InDelaySlot;
                        instvalid <= `InstValid;
                        branch_target_address_o <= {pc_plus_4[31:28], inst_i[25:0], 2'b00};
                    end
                `EXE_JAL:
                    begin // jal指令
                        wreg_o <= `WriteEnable;
                        aluop_o <= `EXE_JAL_OP;
                        alusel_o <= `EXE_RES_JUMP_BRANCH;
                        reg1_read_o <= 1'b0;
                        reg2_read_o <= 1'b0;
                        wd_o <= 5'b11111;
                        link_addr_o <= pc_plus_8;
                        branch_flag_o <= `Branch;
                        next_inst_in_delayslot_o <= `InDelaySlot;
                        instvalid <= `InstValid;
                        branch_target_address_o <= {pc_plus_4[31:28], inst_i[25:0], 2'b00};
                    end
                `EXE_BEQ:
                    begin // beq指令 
                        wreg_o <= `WriteDisable;
                        aluop_o <= `EXE_BEQ_OP;
                        alusel_o <= `EXE_RES_JUMP_BRANCH;
                        reg1_read_o <= 1'b1;
                        reg2_read_o <= 1'b1;
                        instvalid <= `InstValid;
                        if(reg1_o == reg2_o)
                            begin 
                                branch_target_address_o  <= pc_plus_4 + imm_sll2_signedext;
                                branch_flag_o <= `Branch;
                                next_inst_in_delayslot_o <= `InDelaySlot; 
                            end 
                    end
                `EXE_BGTZ:
                    begin // bgtz指令 
                        wreg_o <= `WriteDisable;
                        aluop_o <= `EXE_BGTZ_OP;
                        alusel_o <= `EXE_RES_JUMP_BRANCH;
                        reg1_read_o <= 1'b1;
                        reg2_read_o <= 1'b0;
                        instvalid <= `InstValid;
                        if((reg1_o[31] == 1'b0) && (reg1_o != `ZeroWord))
                            begin 
                                branch_target_address_o <= pc_plus_4 + imm_sll2_signedext;
                                branch_flag_o <= `Branch;
                                next_inst_in_delayslot_o <= `InDelaySlot;
                            end 
                    end
                `EXE_BLEZ:
                    begin // blez指令
                        wreg_o <= `WriteDisable;
                        aluop_o <= `EXE_BLEZ_OP;
                        alusel_o <= `EXE_RES_JUMP_BRANCH;
                        reg1_read_o <= 1'b1;
                        reg2_read_o <= 1'b0;
                        instvalid   <= `InstValid; 
                        if((reg1_o[31] == 1'b1) || (reg1_o == `ZeroWord))
                            begin 
                                branch_target_address_o  <= pc_plus_4 + imm_sll2_signedext; 
                                branch_flag_o            <= `Branch; 
                                next_inst_in_delayslot_o <= `InDelaySlot; 
                            end 
                    end 
		  	    `EXE_ANDI:
                    begin
                        wreg_o <= `WriteEnable;
                        aluop_o <= `EXE_AND_OP;
		  		        alusel_o <= `EXE_RES_LOGIC;
                        reg1_read_o <= 1'b1;
                        reg2_read_o <= 1'b0;
					    imm <= {16'h0, inst_i[15:0]};
                        wd_o <= inst_i[20:16];
					    instvalid <= `InstValid;
				    end
		  	    `EXE_XORI:
                    begin
                        wreg_o <= `WriteEnable;
                        aluop_o <= `EXE_XOR_OP;
                        alusel_o <= `EXE_RES_LOGIC;
                        reg1_read_o <= 1'b1;
                        reg2_read_o <= 1'b0;
					    imm <= {16'h0, inst_i[15:0]};
                        wd_o <= inst_i[20:16];
					    instvalid <= `InstValid;
				    end
		  	    `EXE_LUI:
                    begin
                        wreg_o <= `WriteEnable;
                        aluop_o <= `EXE_OR_OP;
		  		        alusel_o <= `EXE_RES_LOGIC;
                        reg1_read_o <= 1'b1;
                        reg2_read_o <= 1'b0;
					    imm <= {inst_i[15:0], 16'h0};
                        wd_o <= inst_i[20:16];
					    instvalid <= `InstValid;
				    end
				`EXE_PREF: // 加载缓存
                    begin
                        wreg_o <= `WriteDisable;
                        aluop_o <= `EXE_NOP_OP;
                        alusel_o <= `EXE_RES_NOP;
                        reg1_read_o <= 1'b0;
                        reg2_read_o <= 1'b0;
                        instvalid <= `InstValid;	
				    end
                `EXE_SLTI:
                    begin                         // slti指令 
                        wreg_o      <= `WriteEnable; 
                        aluop_o     <= `EXE_SLT_OP; 
                        alusel_o    <= `EXE_RES_ARITHMETIC;  
                        reg1_read_o <= 1'b1;  
                        reg2_read_o <= 1'b0; 
                        imm         <= {{16{inst_i[15]}}, inst_i[15:0]}; 
                        wd_o        <= inst_i[20:16]; 
                        instvalid   <= `InstValid; 
                    end
                `EXE_SLTIU:
                    begin                      // sltiu指令 
                        wreg_o      <= `WriteEnable; 
                        aluop_o     <= `EXE_SLTU_OP;
                        aluop_o     <= `EXE_SLTU_OP; 
                        alusel_o    <= `EXE_RES_ARITHMETIC;  
                        reg1_read_o <= 1'b1; 
                        reg2_read_o <= 1'b0; 
                        imm         <= {{16{inst_i[15]}}, inst_i[15:0]}; 
                        wd_o        <= inst_i[20:16]; 
                        instvalid   <= `InstValid; 
                    end
                `EXE_ADDI:
                    begin                      // addi指令 
                        wreg_o      <= `WriteEnable; 
                        aluop_o     <= `EXE_ADDI_OP; 
                        alusel_o    <= `EXE_RES_ARITHMETIC;  
                        reg1_read_o <= 1'b1; 
                        reg2_read_o <= 1'b0; 
                        imm         <= {{16{inst_i[15]}}, inst_i[15:0]}; 
                        wd_o        <= inst_i[20:16];  
                        instvalid   <= `InstValid; 
                    end
                `EXE_ADDIU:
                    begin                         // addiu指令 
                        wreg_o      <= `WriteEnable; 
                        aluop_o     <= `EXE_ADDIU_OP; 
                        alusel_o    <= `EXE_RES_ARITHMETIC;  
                        reg1_read_o <= 1'b1; reg2_read_o <= 1'b0; 
                        imm         <= {{16{inst_i[15]}}, inst_i[15:0]}; 
                        wd_o        <= inst_i[20:16]; 
                        instvalid   <= `InstValid; 
                    end
                `EXE_REGIMM_INST:
                    begin
                        case (op4) 
                            `EXE_BGEZ:
                                begin // bgez指令 
                                    wreg_o <= `WriteDisable;
                                    aluop_o <= `EXE_BGEZ_OP;
                                    alusel_o <= `EXE_RES_JUMP_BRANCH;
                                    reg1_read_o <= 1'b1;
                                    reg2_read_o <= 1'b0;
                                    instvalid <= `InstValid;
                                    if(reg1_o[31] == 1'b0)
                                        begin
                                            branch_target_address_o <= pc_plus_4 + imm_sll2_signedext;
                                            branch_flag_o <= `Branch; 
                                            next_inst_in_delayslot_o <= `InDelaySlot;
                                        end
                                end
                            `EXE_BGEZAL:
                                begin // bgezal指令 
                                    wreg_o <= `WriteEnable;
                                    aluop_o <= `EXE_BGEZAL_OP;
                                    alusel_o <= `EXE_RES_JUMP_BRANCH;
                                    reg1_read_o <= 1'b1;
                                    reg2_read_o <= 1'b0;
                                    link_addr_o <= pc_plus_8;
                                    wd_o <= 5'b11111;
                                    instvalid <= `InstValid;
                                    if(reg1_o[31] == 1'b0)
                                        begin
                                            branch_target_address_o <= pc_plus_4 + imm_sll2_signedext;
                                            branch_flag_o <= `Branch;
                                            next_inst_in_delayslot_o <= `InDelaySlot;
                                        end
                                end
                            `EXE_BLTZ:
                                begin // bltz指令 
                                    wreg_o <= `WriteDisable;
                                    aluop_o <= `EXE_BGEZAL_OP;
                                    alusel_o <= `EXE_RES_JUMP_BRANCH;
                                    reg1_read_o <= 1'b1;
                                    reg2_read_o <= 1'b0;
                                    instvalid <= `InstValid;
                                    if(reg1_o[31] == 1'b1)
                                        begin
                                            branch_target_address_o <= pc_plus_4 + imm_sll2_signedext;
                                            branch_flag_o <= `Branch;
                                            next_inst_in_delayslot_o <= `InDelaySlot;
                                        end
                                end
                               end 
                            `EXE_BLTZAL:
                                begin // bltzal指令 
                                    wreg_o <= `WriteEnable;
                                    aluop_o <= `EXE_BGEZAL_OP;
                                    alusel_o <= `EXE_RES_JUMP_BRANCH;
                                    reg1_read_o <= 1'b1;
                                    reg2_read_o <= 1'b0;
                                    link_addr_o <= pc_plus_8;
                                    wd_o <= 5'b11111;
                                    instvalid <= `InstValid;
                                    if(reg1_o[31] == 1'b1)
                                        begin 
                                            branch_target_address_o <= pc_plus_4 + imm_sll2_signedext;
                                            branch_flag_o <= `Branch;
                                            next_inst_in_delayslot_o <= `InDelaySlot; 
                                        end 
                                end 
                            default:
                                begin
                                end
                        endcase
                    end
                `EXE_SPECIAL2_INST:
                    begin
                        case ( op3 ) 
                            `EXE_CLZ:
                                begin                         // clz指令 
                                    wreg_o      <= `WriteEnable;
                                    aluop_o     <= `EXE_CLZ_OP;
                                    alusel_o    <= `EXE_RES_ARITHMETIC;
                                    reg1_read_o <= 1'b1;
                                    reg2_read_o <= 1'b0;
                                    instvalid   <= `InstValid;
                                end
                            `EXE_CLO:
                                begin                          // clo指令 
                                    wreg_o      <= `WriteEnable; 
                                    aluop_o     <= `EXE_CLO_OP; 
                                    alusel_o    <= `EXE_RES_ARITHMETIC;  
                                    reg1_read_o <= 1'b1; 
                                    reg2_read_o <= 1'b0; 
                                    instvalid   <= `InstValid; 
                                end
                            `EXE_MUL:
                                begin                          // mul指令 
                                    wreg_o      <= `WriteEnable; 
                                    aluop_o     <= `EXE_MUL_OP; 
                                    alusel_o    <= `EXE_RES_MUL;  
                                    reg1_read_o <= 1'b1; 
                                    reg2_read_o <= 1'b1; 
                                    instvalid   <= `InstValid;
                                end
                             `EXE_MADD:
                                begin         // madd指令 
                                    wreg_o      <= `WriteDisable; 
                                    aluop_o     <= `EXE_MADD_OP; 
                                    alusel_o    <= `EXE_RES_MUL;  
                                    reg1_read_o <= 1'b1; 
                                    reg2_read_o <= 1'b1; 
                                    instvalid   <= `InstValid; 
                                end 
                            `EXE_MADDU:
                                begin         // maddu指令 
                                    wreg_o      <= `WriteDisable;
                                    aluop_o     <= `EXE_MADDU_OP;
                                    alusel_o    <= `EXE_RES_MUL;
                                    reg1_read_o <= 1'b1;
                                    reg2_read_o <= 1'b1; 
                                    instvalid   <= `InstValid; 
                                end 
                            `EXE_MSUB:
                                begin         // msub指令 
                                    wreg_o      <= `WriteDisable; 
                                    aluop_o     <= `EXE_MSUB_OP; 
                                    alusel_o    <= `EXE_RES_MUL;  
                                    reg1_read_o <= 1'b1;  
                                    reg2_read_o <= 1'b1; 
                                    instvalid   <= `InstValid; 
                                end 
                            `EXE_MSUBU:
                                begin         // msubu指令 
                                    wreg_o      <= `WriteDisable; 
                                    aluop_o     <= `EXE_MSUBU_OP; 
                                    alusel_o    <= `EXE_RES_MUL;
                                    reg1_read_o <= 1'b1;  
                                    reg2_read_o <= 1'b1; 
                                    instvalid   <= `InstValid;  
                                end 
                            default:
                                begin
                                end
                        endcase      //EXE_SPECIAL_INST2 case 
                    end
		        default:
                    begin
		            end
            endcase		  //case op
		  
            if (inst_i[31:21] == 11'b00000000000)
                begin
                    if (op3 == `EXE_SLL)
                        begin
                            wreg_o <= `WriteEnable;
                            aluop_o <= `EXE_SLL_OP;
                            alusel_o <= `EXE_RES_SHIFT;
                            reg1_read_o <= 1'b0;
                            reg2_read_o <= 1'b1;
					        imm[4:0] <= inst_i[10:6];
                            wd_o <= inst_i[15:11];
					        instvalid <= `InstValid;
				        end
                    else if ( op3 == `EXE_SRL )
                        begin
		  		            wreg_o <= `WriteEnable;
                            aluop_o <= `EXE_SRL_OP;
		  		            alusel_o <= `EXE_RES_SHIFT;
                            reg1_read_o <= 1'b0;
                            reg2_read_o <= 1'b1;
					        imm[4:0] <= inst_i[10:6];
                            wd_o <= inst_i[15:11];
					        instvalid <= `InstValid;
				        end
                    else if ( op3 == `EXE_SRA )
                        begin
		  		            wreg_o <= `WriteEnable;
                            aluop_o <= `EXE_SRA_OP;
		  		            alusel_o <= `EXE_RES_SHIFT;
                            reg1_read_o <= 1'b0;
                            reg2_read_o <= 1'b1;
                            imm[4:0] <= inst_i[10:6];
                            wd_o <= inst_i[15:11];
                            instvalid <= `InstValid;
				        end
			    end
		  
		end
end

always @ (*) 
begin
    if(rst == `RstEnable)
        begin
            reg1_o <= `ZeroWord;
        end
    else if((reg1_read_o == 1'b1) && (ex_wreg_i == 1'b1) && (ex_wd_i == reg1_addr_o))
        begin
              reg1_o <= ex_wdata_i;
        end
    else if((reg1_read_o == 1'b1) && (mem_wreg_i == 1'b1) && (mem_wd_i == reg1_addr_o))
        begin
              reg1_o <= mem_wdata_i;
         end
    else if(reg1_read_o == 1'b1)
        begin
            reg1_o <= reg1_data_i;    // Regfile读端口1的输出值
        end
    else if(reg1_read_o == 1'b0)
        begin
            reg1_o <= imm;             // 立即数
        end
    else
        begin
            reg1_o <= `ZeroWord;
        end
end

always @ (*)
begin
    if(rst == `RstEnable)
        begin
            reg2_o <= `ZeroWord;
        end
    else if((reg2_read_o == 1'b1) && (ex_wreg_i == 1'b1) && (ex_wd_i == reg2_addr_o))
        begin
              reg2_o <= ex_wdata_i;
         end
    else if((reg1_read_o == 1'b1) && (mem_wreg_i == 1'b1) && (mem_wd_i == reg2_addr_o))
        begin
              reg2_o <= mem_wdata_i;
         end
    else if(reg2_read_o == 1'b1)
        begin
            reg2_o <= reg2_data_i;    // Regfile读端口2的输出值
        end
    else if(reg2_read_o == 1'b0)
        begin
            reg2_o <= imm;             // 立即数
        end
    else
        begin
            reg2_o <= `ZeroWord;
       end
end

always @ (*)
    begin 
        if(rst == `RstEnable)
            begin
                is_in_delayslot_o <= `NotInDelaySlot;
            end
        else
            begin
                // 直接等于is_in_delayslot_i
                is_in_delayslot_o <= is_in_delayslot_i;
            end
    end

endmodule